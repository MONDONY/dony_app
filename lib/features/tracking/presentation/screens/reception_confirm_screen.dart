import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';

/// Confirmation de livraison côté voyageur : saisie directe du code de
/// retrait à 6 chiffres communiqué par l'expéditeur. Dispatche
/// [ConfirmDeliveryRequested] sur le [TrackingBloc] fourni par la route
/// `/tracking/confirm`.
class ReceptionConfirmScreen extends StatefulWidget {
  const ReceptionConfirmScreen({super.key, required this.bidId});

  final String bidId;

  @override
  State<ReceptionConfirmScreen> createState() => _ReceptionConfirmScreenState();
}

class _ReceptionConfirmScreenState extends State<ReceptionConfirmScreen> {
  static const _kCodeLength = 6;

  final _codeController = TextEditingController();
  final _codeComplete = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _codeController.addListener(() {
      _codeComplete.value = _codeController.text.trim().length == _kCodeLength;
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _codeComplete.dispose();
    super.dispose();
  }

  void _confirm() {
    context.read<TrackingBloc>().add(
      ConfirmDeliveryRequested(
        bidId: widget.bidId,
        code: _codeController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const DonyAppBar(title: 'Confirmation'),
      body: BlocConsumer<TrackingBloc, TrackingState>(
        listenWhen: (_, s) =>
            s is DeliveryConfirmSuccess || s is DeliveryConfirmError,
        listener: (context, state) {
          if (state is DeliveryConfirmSuccess) {
            DonySnackbar.show(
              context,
              message: 'Livraison confirmée',
              type: DonySnackbarType.success,
            );
            if (context.canPop()) {
              context.pop();
            }
          } else if (state is DeliveryConfirmError) {
            ErrorPresenter.show(context, state.error);
          }
        },
        buildWhen: (_, s) =>
            s is DeliveryConfirmLoading ||
            s is DeliveryConfirmSuccess ||
            s is DeliveryConfirmError,
        builder: (context, state) {
          final isLoading = state is DeliveryConfirmLoading;
          final h = DonyLayout.hPadding(context);
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              h,
              DonySpacing.xs,
              h,
              DonySpacing.huge,
            ),
            child: DonyLayout.constrained(
              context,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: DonyMascotteAnimated(
                      type: DonyMascotteType.confiant,
                    ),
                  ),
                  const SizedBox(height: DonySpacing.base),
                  Text(
                    'Confirmer la livraison',
                    style: DonyTypography.caveat(
                      fontSize: 28,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: DonySpacing.xs),
                  Text(
                    'Saisissez le code de retrait à 6 chiffres que '
                    "l'expéditeur vous a communiqué.",
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: DonySpacing.xl),
                  Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Pinput(
                        length: _kCodeLength,
                        controller: _codeController,
                        autofocus: true,
                        defaultPinTheme: _pinTheme(cs, tt, focused: false),
                        focusedPinTheme: _pinTheme(cs, tt, focused: true),
                      ),
                    ),
                  ),
                  const SizedBox(height: DonySpacing.xl),
                  ValueListenableBuilder<bool>(
                    valueListenable: _codeComplete,
                    builder: (context, complete, _) => DonyButton(
                      label: 'Confirmer la livraison',
                      icon: Icons.check_rounded,
                      isLoading: isLoading,
                      onPressed: (complete && !isLoading) ? _confirm : null,
                    ),
                  ),
                  const SizedBox(height: DonySpacing.lg),
                  const _LegalNote(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  PinTheme _pinTheme(ColorScheme cs, TextTheme tt, {required bool focused}) =>
      PinTheme(
        width: 52,
        height: 60,
        textStyle: tt.headlineMedium?.copyWith(
          color: cs.onSurface,
          fontWeight: FontWeight.w700,
        ),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.card),
          border: Border.all(
            color: focused ? cs.primary : cs.outline,
            width: focused ? 2 : 1.5,
          ),
        ),
      );
}

// ── Legal note ────────────────────────────────────────────────────────────────

class _LegalNote extends StatelessWidget {
  const _LegalNote();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.shield_outlined,
            size: DonySpacing.iconSm,
            color: cs.onSurfaceVariant,
          ),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                children: [
                  const TextSpan(
                    text:
                        'En confirmant, vous validez la remise du colis '
                        'au destinataire. Si quelque chose ne va pas, ',
                  ),
                  WidgetSpan(
                    child: GestureDetector(
                      onTap: () => context.push('/disputes'),
                      child: Text(
                        'contestez d\'abord',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
