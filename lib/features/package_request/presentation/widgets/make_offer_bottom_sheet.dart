import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/design/widgets/dony_bottom_sheet.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/models/price_estimate.dart';
import 'package:dony/features/package_request/data/price_estimation_repository.dart';
import 'package:dony/features/package_request/presentation/_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

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
    PriceEstimate? estimate;
    try {
      estimate = await getIt<PriceEstimationRepository>().estimate(
        from: departureCity,
        to: arrivalCity,
        weight: weightKg,
      );
    } catch (_) {
      // estimate optional
    }

    if (!context.mounted) return;

    // Capture root references BEFORE the sheet opens — using `ctx` from
    // inside the listener after pop() would touch a disposed subtree.
    final rootRouter = GoRouter.of(context);

    VoidCallback? submitFn;

    await DonyBottomSheet.show<void>(
      context,
      title: 'Faire une offre',
      wrapper: (child) => BlocProvider(
        create: (_) => getIt<NegotiationBloc>(),
        child: child,
      ),
      child: _MakeOfferContent(
        packageRequestId: packageRequestId,
        targetPriceEur: targetPriceEur,
        weightKg: weightKg,
        estimate: estimate,
        rootRouter: rootRouter,
        onSubmitReady: (fn) => submitFn = fn,
      ),
      stickyBottom: BlocBuilder<NegotiationBloc, NegotiationState>(
        builder: (ctx, state) {
          final loading = state is NegotiationLoading;
          return DonyButton(
            label: loading ? 'Envoi…' : 'Envoyer l\'offre',
            isLoading: loading,
            onPressed: loading ? null : () => submitFn?.call(),
          );
        },
      ),
    );
  }
}

class _MakeOfferContent extends StatefulWidget {
  const _MakeOfferContent({
    required this.packageRequestId,
    required this.targetPriceEur,
    required this.weightKg,
    required this.estimate,
    required this.rootRouter,
    required this.onSubmitReady,
  });

  final String packageRequestId;
  final double? targetPriceEur;
  final double weightKg;
  final PriceEstimate? estimate;
  final GoRouter rootRouter;
  final void Function(VoidCallback) onSubmitReady;

  @override
  State<_MakeOfferContent> createState() => _MakeOfferContentState();
}

class _MakeOfferContentState extends State<_MakeOfferContent> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _priceCtrl;
  late final TextEditingController _kgCtrl;
  late final TextEditingController _bodyCtrl;
  final _dateNotifier = ValueNotifier<DateTime?>(null);

  @override
  void initState() {
    super.initState();
    widget.onSubmitReady(_submit);
    _priceCtrl = TextEditingController(
      text: widget.targetPriceEur != null
          ? widget.targetPriceEur!.toStringAsFixed(0)
          : '',
    );
    _kgCtrl = TextEditingController(text: widget.weightKg.toStringAsFixed(1));
    _bodyCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _kgCtrl.dispose();
    _bodyCtrl.dispose();
    _dateNotifier.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_dateNotifier.value == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez votre date de voyage')),
      );
      return;
    }
    context.read<NegotiationBloc>().add(NegotiationStartRequested(
          packageRequestId: widget.packageRequestId,
          proposedPriceEur:
              double.parse(_priceCtrl.text.replaceAll(',', '.')),
          travelerTravelDate: _dateNotifier.value!,
          travelerAvailableKg:
              double.parse(_kgCtrl.text.replaceAll(',', '.')),
          body: _bodyCtrl.text.trim().isEmpty ? null : _bodyCtrl.text.trim(),
        ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final estimate = widget.estimate;
    final tt = Theme.of(context).textTheme;
    return BlocListener<NegotiationBloc, NegotiationState>(
      listener: (ctx, state) {
        if (state is NegotiationLoaded) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            const SnackBar(
              content: Text('Offre envoyée'),
              backgroundColor: kSuccess,
            ),
          );
          // Pop sheet first, then push using the captured root router so we
          // don't dereference a disposed subtree context.
          Navigator.of(ctx, rootNavigator: true).pop();
          widget.rootRouter.push('/negotiations/${state.thread.id}');
        } else if (state is NegotiationError) {
          ErrorPresenter.show(ctx, state.error);
        }
      },
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (estimate != null && estimate.lowEur != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(DonyRadius.md),
                ),
                child: Row(
                  children: [
                    Icon(Icons.trending_up_rounded,
                        color: cs.primary, size: 20),
                    const SizedBox(width: DonySpacing.md),
                    Expanded(
                      child: Text(
                        'Estimation : ${estimate.lowEur!.toStringAsFixed(0)}–${estimate.highEur!.toStringAsFixed(0)} € (${estimate.confidence.wireName.toLowerCase()})',
                        style: tt.bodyMedium!.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: cs.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: DonySpacing.base),
            TextFormField(
              controller: _priceCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
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
            const SizedBox(height: DonySpacing.md),
            TextFormField(
              controller: _kgCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
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
            const SizedBox(height: DonySpacing.md),
            ValueListenableBuilder<DateTime?>(
              valueListenable: _dateNotifier,
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
                  if (picked != null) _dateNotifier.value = picked;
                },
                borderRadius: BorderRadius.circular(DonyRadius.md),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: DonySpacing.base, vertical: 18),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(DonyRadius.md),
                    border: Border.all(color: cs.outline),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded,
                          size: 20, color: kTextSecondary),
                      const SizedBox(width: DonySpacing.md),
                      Text(
                        date == null
                            ? 'Date de voyage'
                            : '${date.day}/${date.month}/${date.year}',
                        style: tt.bodyMedium!.copyWith(
                          fontSize: 15,
                          color: date == null ? kTextHint : kTextPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: DonySpacing.md),
            TextFormField(
              controller: _bodyCtrl,
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
  }
}
