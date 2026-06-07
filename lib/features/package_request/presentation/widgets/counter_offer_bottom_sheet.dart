import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/design/widgets/dony_bottom_sheet.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/models/price_display.dart';
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
  }) {
    final submitNotifier = ValueNotifier<VoidCallback?>(null);

    return DonyBottomSheet.show<void>(
      context,
      title: 'Faire une contre-offre',
      wrapper: (child) => BlocProvider.value(value: bloc, child: child),
      stickyBottom: ValueListenableBuilder<VoidCallback?>(
        valueListenable: submitNotifier,
        builder: (_, fn, __) => DonyButton(
          label: 'Envoyer ma contre-offre',
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
        onSubmitReady: (fn) => WidgetsBinding.instance
            .addPostFrameCallback((_) => submitNotifier.value = fn),
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
  });

  final NegotiationBloc bloc;
  final String threadId;
  final double currentPriceEur;
  final double? grossPriceEur;
  final bool isTraveler;
  final int roundsCount;
  final void Function(VoidCallback?) onSubmitReady;

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
    final isValid = d != null && d > 0 && d <= 500;
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
    widget.bloc.add(NegotiationCounterRequested(
      threadId: widget.threadId,
      proposedPriceEur:
          double.parse(_priceCtrl.text.replaceAll(',', '.')),
      body: _bodyCtrl.text.trim().isEmpty ? null : _bodyCtrl.text.trim(),
    ));
    Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sous-titre : prix actuel (rôle-aware) + round
          Text(
            '${PriceDisplay.threadPriceLabel(widget.currentPriceEur, widget.grossPriceEur, widget.isTraveler)} · Round ${widget.roundsCount}/5',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: DonySpacing.xl),

          // Label prix
          Text(
            'Ton prix proposé',
            style: tt.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: DonySpacing.sm),

          // Champ prix — grand format comme maquette
          TextFormField(
            controller: _priceCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d,.]'))
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
              suffixText: '€',
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
                borderSide:
                    BorderSide(color: cs.primary, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(DonyRadius.md),
                borderSide:
                    BorderSide(color: DonyColors.danger500),
              ),
            ),
            validator: (v) {
              final d =
                  double.tryParse((v ?? '').replaceAll(',', '.'));
              if (d == null || d <= 0) return 'Valeur invalide';
              if (d > 500) return 'Maximum 500 €';
              return null;
            },
          ),
          const SizedBox(height: DonySpacing.xl),

          // Label message
          Text(
            'Message (optionnel)',
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
            buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '$currentLength/${maxLength ?? 280}',
                    style: tt.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
            style: tt.bodyLarge,
            decoration: InputDecoration(
              hintText: 'Explique ta proposition…',
              hintStyle: tt.bodyLarge
                  ?.copyWith(color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
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
                borderSide:
                    BorderSide(color: cs.primary, width: 2),
              ),
            ),
          ),
          const SizedBox(height: DonySpacing.sm),
        ],
      ),
    );
  }
}
