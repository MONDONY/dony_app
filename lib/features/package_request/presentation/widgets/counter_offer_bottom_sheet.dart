import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/models/price_display.dart';
import 'package:dony/features/package_request/presentation/package_request_labels.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CounterOfferBottomSheet {
  const CounterOfferBottomSheet._();

  static Future<void> show(
    BuildContext context, {
    required NegotiationBloc bloc,
    required String threadId,
    required double currentPriceEur,
    double? grossPriceEur,
    bool isTraveler = false,
    int roundsCount = 1,
    String currency = 'EUR',
  }) {
    final submitNotifier = ValueNotifier<VoidCallback?>(null);

    return DonyBottomSheet.show<void>(
      context,
      title: context.l10n.negotiationCounterOfferTitle,
      wrapper: (child) => BlocProvider.value(value: bloc, child: child),
      stickyBottom: ValueListenableBuilder<VoidCallback?>(
        valueListenable: submitNotifier,
        builder: (ctx, fn, _) => DonyButton(
          label: ctx.l10n.negotiationThreadCounterSubmitButton,
          onPressed: fn,
        ),
      ),
      child: _CounterOfferContent(
        bloc: bloc,
        threadId: threadId,
        currentPriceEur: currentPriceEur,
        grossPriceEur: grossPriceEur,
        isTraveler: isTraveler,
        roundsCount: roundsCount,
        currency: currency,
        onSubmitReady: (fn) => WidgetsBinding.instance.addPostFrameCallback(
          (_) => submitNotifier.value = fn,
        ),
      ),
    ).whenComplete(submitNotifier.dispose);
  }
}

class _CounterOfferContent extends StatefulWidget {
  const _CounterOfferContent({
    required this.bloc,
    required this.threadId,
    required this.currentPriceEur,
    this.grossPriceEur,
    this.isTraveler = false,
    required this.roundsCount,
    required this.onSubmitReady,
    this.currency = 'EUR',
  });

  final NegotiationBloc bloc;
  final String threadId;
  final double currentPriceEur;
  final double? grossPriceEur;
  final bool isTraveler;
  final int roundsCount;
  final void Function(VoidCallback?) onSubmitReady;
  final String currency;

  @override
  State<_CounterOfferContent> createState() => _CounterOfferContentState();
}

class _CounterOfferContentState extends State<_CounterOfferContent> {
  final _formKey = GlobalKey<FormState>();
  final _priceCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  bool _valid = false;

  @override
  void initState() {
    super.initState();
    _priceCtrl.addListener(_validate);
    _bodyCtrl.addListener(_validate);
  }

  void _validate() {
    final d = double.tryParse(_priceCtrl.text.replaceAll(',', '.'));
    // Aucun plafond métier : le garde-fou technique (1 000 000) vit côté serveur.
    final isValid = d != null && d > 0;
    if (isValid != _valid) {
      setState(() => _valid = isValid);
      widget.onSubmitReady(isValid ? _submit : null);
    }
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    widget.bloc.add(
      NegotiationCounterRequested(
        threadId: widget.threadId,
        proposedPriceEur: double.parse(_priceCtrl.text.replaceAll(',', '.')),
        body: _bodyCtrl.text.trim().isEmpty ? null : _bodyCtrl.text.trim(),
      ),
    );
    Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sous-titre : prix actuel (rôle-aware) + round
          Text(
            l.negotiationCounterOfferSubtitle(
              threadPriceLabel(
                l,
                widget.currentPriceEur,
                widget.grossPriceEur,
                widget.isTraveler,
                widget.currency,
              ),
              widget.roundsCount,
            ),
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: DonySpacing.xl),

          // Label prix
          Text(
            l.negotiationCounterOfferYourPriceLabel,
            style: tt.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: DonySpacing.sm),

          // Champ prix — grand format comme maquette
          TextFormField(
            controller: _priceCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d,.]')),
            ],
            autofocus: true,
            style: tt.bodyMedium!.copyWith(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
              letterSpacing: -0.5,
            ),
            decoration: InputDecoration(
              hintText: '0',
              hintStyle: tt.bodyMedium!.copyWith(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: cs.onSurfaceVariant.withValues(alpha: 0.4),
              ),
              suffixText: SupportedCurrency.symbolOf(widget.currency),
              suffixStyle: tt.bodyMedium!.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: DonySpacing.base,
                vertical: DonySpacing.base,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(DonyRadius.md),
                borderSide: BorderSide(color: cs.outline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(DonyRadius.md),
                borderSide: BorderSide(color: cs.outline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(DonyRadius.md),
                borderSide: BorderSide(color: cs.primary, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(DonyRadius.md),
                borderSide: const BorderSide(color: DonyColors.danger500),
              ),
            ),
            validator: (v) {
              final d = double.tryParse((v ?? '').replaceAll(',', '.'));
              if (d == null || d <= 0) return l.requestCreateWeightInvalid;
              return null;
            },
          ),
          // Le prix saisi est le net du voyageur : sans ce détail, l'expéditeur
          // voyait son montant revenir majoré sans savoir que c'était la
          // commission Yadony (FLUTTER-Q5).
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _priceCtrl,
            builder: (_, value, _) {
              final net = double.tryParse(value.text.replaceAll(',', '.'));
              if (net == null || net <= 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: DonySpacing.md),
                child: CounterOfferCommissionPreview(
                  net: net,
                  isTraveler: widget.isTraveler,
                  currency: widget.currency,
                ),
              );
            },
          ),
          const SizedBox(height: DonySpacing.xl),

          // Label message
          Text(
            l.negotiationCounterOfferMessageLabel,
            style: tt.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: DonySpacing.sm),

          // Champ message
          TextFormField(
            controller: _bodyCtrl,
            maxLines: 3,
            maxLength: 280,
            buildCounter:
                (_, {required currentLength, required isFocused, maxLength}) =>
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '$currentLength/${maxLength ?? 280}',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
            style: tt.bodyLarge,
            decoration: InputDecoration(
              hintText: l.negotiationCounterOfferMessageHint,
              hintStyle: tt.bodyLarge?.copyWith(
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
              ),
              contentPadding: const EdgeInsets.all(DonySpacing.base),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(DonyRadius.md),
                borderSide: BorderSide(color: cs.outline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(DonyRadius.md),
                borderSide: BorderSide(color: cs.outline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(DonyRadius.md),
                borderSide: BorderSide(color: cs.primary, width: 2),
              ),
            ),
          ),
          const SizedBox(height: DonySpacing.sm),
        ],
      ),
    );
  }
}

/// Détail du prix proposé : net du voyageur, commission Yadony et total payé
/// par l'expéditeur, lu dans l'ordre qui concerne chaque rôle (même calcul que
/// l'en-tête du fil, [PriceDisplay.grossFromNet]).
@visibleForTesting
class CounterOfferCommissionPreview extends StatelessWidget {
  const CounterOfferCommissionPreview({
    required this.net,
    required this.isTraveler,
    required this.currency,
    super.key,
  });

  final double net;
  final bool isTraveler;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final fee = PriceDisplay.feeFromNet(net);
    final gross = PriceDisplay.grossFromNet(net);
    final commission = l.requestCreateCommissionLabel;

    Widget line(String label, String amount, {bool strong = false}) {
      final style = (strong ? tt.titleSmall : tt.bodyMedium)?.copyWith(
        color: strong ? cs.onSurface : cs.onSurfaceVariant,
        fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(child: Text(label, style: style)),
            const SizedBox(width: DonySpacing.sm),
            Text(amount, style: style),
          ],
        ),
      );
    }

    String money(double v) => PriceDisplay.money(v, currency);

    return Container(
      key: const Key('counter-offer-commission-preview'),
      padding: const EdgeInsets.all(DonySpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(DonyRadius.md),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: isTraveler
            ? [
                line(l.negotiationPriceBreakdownPaidBySender, money(gross)),
                line(commission, '−${money(fee)}'),
                line(
                  l.negotiationPriceBreakdownYouReceive,
                  money(net),
                  strong: true,
                ),
              ]
            : [
                line(l.negotiationPriceBreakdownNetTraveler, money(net)),
                line(commission, money(fee)),
                line(
                  l.negotiationPriceBreakdownTotalToSettle,
                  money(gross),
                  strong: true,
                ),
              ],
      ),
    );
  }
}
