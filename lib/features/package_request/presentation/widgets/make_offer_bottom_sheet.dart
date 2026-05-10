import 'package:dony/core/design/widgets/dony_bottom_sheet.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/models/price_estimate.dart';
import 'package:dony/features/package_request/data/price_estimation_repository.dart';
import 'package:dony/features/package_request/presentation/_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class MakeOfferBottomSheet {
  const MakeOfferBottomSheet._();

  static Future<void> show(
    BuildContext context, {
    required String packageRequestId,
    double? targetPriceEur,
    required double weightKg,
    required String departureCity,
    required String arrivalCity,
  }) async {
    final formKey = GlobalKey<FormState>();
    final priceCtrl = TextEditingController(
      text: targetPriceEur != null ? targetPriceEur.toStringAsFixed(0) : '',
    );
    final kgCtrl = TextEditingController(text: weightKg.toStringAsFixed(1));
    final dateNotifier = ValueNotifier<DateTime?>(null);
    final bodyCtrl = TextEditingController();

    PriceEstimate? estimate;
    try {
      estimate = await getIt<PriceEstimationRepository>().estimate(
        from: departureCity,
        to: arrivalCity,
        weight: weightKg,
      );
    } catch (_) {
      // ignore
    }

    if (!context.mounted) return;
    await DonyBottomSheet.show<void>(
      context,
      title: 'Faire une offre',
      wrapper: (child) => BlocProvider(
        create: (_) => getIt<NegotiationBloc>(),
        child: child,
      ),
      stickyBottom: BlocConsumer<NegotiationBloc, NegotiationState>(
        listener: (ctx, state) {
          if (state is NegotiationLoaded) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              const SnackBar(
                content: Text('Offre envoyée'),
                backgroundColor: kSuccess,
              ),
            );
            Navigator.of(ctx, rootNavigator: true).pop();
            ctx.push('/negotiations/${state.thread.id}');
          } else if (state is NegotiationError) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: kError),
            );
          }
        },
        builder: (ctx, state) {
          final loading = state is NegotiationLoading;
          return DonyButton(
            label: loading ? 'Envoi…' : 'Envoyer l\'offre',
            isLoading: loading,
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              if (dateNotifier.value == null) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Sélectionnez votre date de voyage'),
                  ),
                );
                return;
              }
              ctx.read<NegotiationBloc>().add(NegotiationStartRequested(
                    packageRequestId: packageRequestId,
                    proposedPriceEur: double.parse(
                        priceCtrl.text.replaceAll(',', '.')),
                    travelerTravelDate: dateNotifier.value!,
                    travelerAvailableKg: double.parse(
                        kgCtrl.text.replaceAll(',', '.')),
                    body: bodyCtrl.text.trim().isEmpty
                        ? null
                        : bodyCtrl.text.trim(),
                  ));
            },
          );
        },
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (estimate != null && estimate.lowEur != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: kGreenLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.trending_up_rounded,
                        color: kGreenPrimary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Estimation : ${estimate.lowEur!.toStringAsFixed(0)}–${estimate.highEur!.toStringAsFixed(0)} € (${estimate.confidence.wireName.toLowerCase()})',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: kGreenDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Votre prix',
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
              controller: kgCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Capacité disponible',
                suffixText: 'kg',
              ),
              validator: (v) {
                final d = double.tryParse((v ?? '').replaceAll(',', '.'));
                if (d == null || d <= 0) return 'Doit être > 0';
                return null;
              },
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<DateTime?>(
              valueListenable: dateNotifier,
              builder: (ctx, date, _) => InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: date ??
                        DateTime.now().add(const Duration(days: 7)),
                    firstDate: DateTime.now(),
                    lastDate:
                        DateTime.now().add(const Duration(days: 90)),
                  );
                  if (picked != null) dateNotifier.value = picked;
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 18),
                  decoration: BoxDecoration(
                    color: kSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded,
                          size: 20, color: kTextSecondary),
                      const SizedBox(width: 12),
                      Text(
                        date == null
                            ? 'Date de voyage'
                            : '${date.day}/${date.month}/${date.year}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          color: date == null ? kTextHint : kTextPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: bodyCtrl,
              maxLines: 2,
              maxLength: 280,
              decoration: const InputDecoration(
                labelText: 'Message (optionnel)',
                hintText: 'Je voyage exactement ce jour-là',
              ),
            ),
          ],
        ),
      ),
    );

    priceCtrl.dispose();
    kgCtrl.dispose();
    bodyCtrl.dispose();
    dateNotifier.dispose();
  }
}
