import 'package:dony/core/design/widgets/dony_bottom_sheet.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/presentation/_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

class CounterOfferBottomSheet {
  const CounterOfferBottomSheet._();

  static Future<void> show(
    BuildContext context, {
    required NegotiationBloc bloc,
    required String threadId,
    required double currentPriceEur,
  }) {
    return DonyBottomSheet.show<void>(
      context,
      title: 'Contre-offre',
      wrapper: (child) => BlocProvider.value(value: bloc, child: child),
      child: _CounterOfferContent(
        bloc: bloc,
        threadId: threadId,
        currentPriceEur: currentPriceEur,
      ),
    );
  }
}

class _CounterOfferContent extends StatefulWidget {
  const _CounterOfferContent({
    required this.bloc,
    required this.threadId,
    required this.currentPriceEur,
  });

  final NegotiationBloc bloc;
  final String threadId;
  final double currentPriceEur;

  @override
  State<_CounterOfferContent> createState() => _CounterOfferContentState();
}

class _CounterOfferContentState extends State<_CounterOfferContent> {
  final _formKey = GlobalKey<FormState>();
  final _priceCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();

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
      proposedPriceEur: double.parse(_priceCtrl.text.replaceAll(',', '.')),
      body: _bodyCtrl.text.trim().isEmpty ? null : _bodyCtrl.text.trim(),
    ));
    Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Prix actuel : ${widget.currentPriceEur.toStringAsFixed(0)} €',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: kTextSecondary,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _priceCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Votre contre-offre',
              suffixText: '€',
            ),
            validator: (v) {
              final d = double.tryParse((v ?? '').replaceAll(',', '.'));
              if (d == null) return 'Valeur invalide';
              if (d <= 0 || d > 500) return 'Entre 0.01 et 500€';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _bodyCtrl,
            maxLines: 2,
            maxLength: 280,
            decoration: const InputDecoration(
              labelText: 'Message (optionnel)',
            ),
          ),
          const SizedBox(height: 16),
          BlocBuilder<NegotiationBloc, NegotiationState>(
            bloc: widget.bloc,
            builder: (ctx, state) {
              final loading = state is NegotiationActionInProgress ||
                  state is NegotiationLoading;
              return DonyButton(
                label: loading ? 'Envoi…' : 'Envoyer',
                isLoading: loading,
                onPressed: loading ? null : _submit,
              );
            },
          ),
        ],
      ),
    );
  }
}
