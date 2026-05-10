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
  }) async {
    final formKey = GlobalKey<FormState>();
    final priceCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();

    await DonyBottomSheet.show<void>(
      context,
      title: 'Contre-offre',
      wrapper: (child) => BlocProvider.value(value: bloc, child: child),
      stickyBottom: BlocBuilder<NegotiationBloc, NegotiationState>(
        bloc: bloc,
        builder: (ctx, state) {
          final loading = state is NegotiationActionInProgress ||
              state is NegotiationLoading;
          return DonyButton(
            label: loading ? 'Envoi…' : 'Envoyer',
            isLoading: loading,
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              bloc.add(NegotiationCounterRequested(
                threadId: threadId,
                proposedPriceEur:
                    double.parse(priceCtrl.text.replaceAll(',', '.')),
                body: bodyCtrl.text.trim().isEmpty
                    ? null
                    : bodyCtrl.text.trim(),
              ));
              Navigator.of(ctx, rootNavigator: true).pop();
            },
          );
        },
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Prix actuel : ${currentPriceEur.toStringAsFixed(0)} €',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: kTextSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: priceCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
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
              controller: bodyCtrl,
              maxLines: 2,
              maxLength: 280,
              decoration: const InputDecoration(
                labelText: 'Message (optionnel)',
              ),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      priceCtrl.dispose();
      bodyCtrl.dispose();
    });
  }
}
