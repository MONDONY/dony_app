import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/get_it_safe.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:pinput/pinput.dart';

/// Sheets « code de retour » (annulation après remise, D7).
///
/// - [ReturnCodeSheet] (expéditeur) : affiche le code détenu par l'expéditeur +
///   le délai + l'état de la restitution. Le voyageur saisira ce code en rendant
///   le colis. Consomme [CancellationBloc] (fourni par valeur depuis l'écran).
/// - [ReturnEntrySheet] (voyageur) : saisie du code à 6 chiffres → confirme la
///   restitution (`ReturnConfirmRequested`).

// ── Expéditeur : afficher le code de retour ───────────────────────────────────

abstract final class ReturnCodeSheet {
  static Future<void> show(
    BuildContext context, {
    required BidModel bid,
    CancellationBloc? cancellationBloc,
  }) async {
    unawaited(HapticFeedback.lightImpact().catchError((_) {}));
    final bloc = cancellationBloc ?? context.read<CancellationBloc>();

    await DonyBottomSheet.show<void>(
      context,
      title: 'Code de retour',
      subtitle: 'À communiquer au voyageur en récupérant votre colis',
      wrapper: (child) =>
          BlocProvider<CancellationBloc>.value(value: bloc, child: child),
      child: _ReturnCodeBody(bid: bid),
    );
  }
}

class _ReturnCodeBody extends StatefulWidget {
  final BidModel bid;
  const _ReturnCodeBody({required this.bid});

  @override
  State<_ReturnCodeBody> createState() => _ReturnCodeBodyState();
}

class _ReturnCodeBodyState extends State<_ReturnCodeBody> {
  @override
  void initState() {
    super.initState();
    // Charge le code frais + l'état du retour (fire l'event return_code_viewed).
    context.read<CancellationBloc>().add(ReturnCodeRequested(widget.bid.id));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CancellationBloc, CancellationState>(
      buildWhen: (_, s) =>
          s is ReturnCodeLoaded ||
          s is CancellationLoading ||
          s is CancellationError,
      builder: (context, state) {
        // Code optimiste depuis le modèle (sender-gated) en attendant le GET.
        String? code = widget.bid.returnCode;
        DateTime? deadline = widget.bid.returnDeadline;
        bool returned = widget.bid.isParcelReturned;
        if (state is ReturnCodeLoaded) {
          code = state.result.returnCode ?? code;
          deadline = state.result.returnDeadline ?? deadline;
          returned = state.result.isReturned || returned;
        }

        if (returned) {
          return const _ReturnedConfirmation();
        }
        return _ReturnCodeContent(code: code, deadline: deadline);
      },
    );
  }
}

class _ReturnCodeContent extends StatelessWidget {
  final String? code;
  final DateTime? deadline;
  const _ReturnCodeContent({required this.code, required this.deadline});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final display = code ?? '••••••';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DonySpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Digits — taille responsive pour ne jamais déborder (6 boxes à largeur
          // fixe débordaient sur écran étroit / textScale élevé).
          LayoutBuilder(
            builder: (_, constraints) {
              final digits = display.split('');
              final n = digits.length;
              const marginPerBox = DonySpacing.xs * 2.0;
              final availableWidth = constraints.maxWidth - (n * marginPerBox);
              final boxWidth = (availableWidth / n).clamp(24.0, 48.0);
              final boxHeight = (boxWidth * 56.0 / 48.0).clamp(28.0, 56.0);
              final fontSize = (boxWidth * 0.5).clamp(13.0, 22.0);
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: digits.map((d) {
                  return Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: DonySpacing.xs,
                    ),
                    width: boxWidth,
                    height: boxHeight,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: DonyColors.ink800,
                      borderRadius: BorderRadius.circular(DonyRadius.md),
                    ),
                    child: Text(
                      d,
                      style: tt.headlineLarge?.copyWith(
                        color: DonyColors.neutral0,
                        fontWeight: FontWeight.w800,
                        fontSize: fontSize,
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: DonySpacing.md),
          if (code != null)
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: code!));
                DonySnackbar.show(
                  context,
                  message: 'Code copié',
                  type: DonySnackbarType.success,
                );
              },
              child: SizedBox(
                height: 44,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: cs.primary),
                    borderRadius: BorderRadius.circular(DonyRadius.md),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      DonyIcon('copy', size: 16, color: cs.primary),
                      const SizedBox(width: DonySpacing.sm),
                      Text(
                        'Copier le code',
                        style: tt.titleSmall?.copyWith(color: cs.primary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: DonySpacing.md),
          Container(
            padding: const EdgeInsets.all(DonySpacing.sm),
            decoration: BoxDecoration(
              color: cs.warningLight,
              borderRadius: BorderRadius.circular(DonyRadius.sm),
              border: Border.all(color: cs.warning.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DonyIcon('info', size: 14, color: cs.warning),
                const SizedBox(width: DonySpacing.sm),
                Expanded(
                  child: Text(
                    deadline != null
                        ? 'Le voyageur doit vous restituer le colis avant le ${_fmtDate(deadline!)}. Donnez-lui ce code uniquement en récupérant votre colis.'
                        : 'Donnez ce code au voyageur uniquement en récupérant votre colis.',
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReturnedConfirmation extends StatelessWidget {
  const _ReturnedConfirmation();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.base,
        vertical: DonySpacing.lg,
      ),
      child: Column(
        children: [
          DonyIcon('circle-check', size: 48, color: cs.success),
          const SizedBox(height: DonySpacing.md),
          Text(
            'Colis restitué',
            style: tt.titleLarge?.copyWith(color: cs.success),
          ),
          const SizedBox(height: DonySpacing.sm),
          Text(
            'Le voyageur a confirmé vous avoir restitué le colis.',
            textAlign: TextAlign.center,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ── Voyageur : saisir le code de retour ───────────────────────────────────────

abstract final class ReturnEntrySheet {
  static Future<void> show(
    BuildContext context, {
    required BidModel bid,
    CancellationBloc? cancellationBloc,
  }) async {
    unawaited(HapticFeedback.lightImpact().catchError((_) {}));
    unawaited(
      getItSafe<AnalyticsService>()?.logEvent(
        AnalyticsEvents.returnCodeEntryOpened,
        properties: {'status': bid.status},
      ),
    );

    final bloc = cancellationBloc ?? context.read<CancellationBloc>();
    final codeNotifier = ValueNotifier<String>('');
    VoidCallback? submit;

    await DonyBottomSheet.show<void>(
      context,
      title: 'Confirmer le retour',
      subtitle: 'Saisissez le code de retour fourni par l\'expéditeur',
      wrapper: (child) =>
          BlocProvider<CancellationBloc>.value(value: bloc, child: child),
      stickyBottom: ValueListenableBuilder<String>(
        valueListenable: codeNotifier,
        builder: (context, code, _) =>
            BlocBuilder<CancellationBloc, CancellationState>(
              builder: (ctx, state) => DonyButton(
                label: 'Confirmer la restitution',
                isLoading: state is CancellationLoading,
                onPressed: code.length < 6 || state is CancellationLoading
                    ? null
                    : () => submit?.call(),
              ),
            ),
      ),
      child: _ReturnEntryBody(
        bid: bid,
        codeNotifier: codeNotifier,
        onSubmitReady: (fn) => submit = fn,
      ),
    ).whenComplete(codeNotifier.dispose);
  }
}

class _ReturnEntryBody extends StatefulWidget {
  final BidModel bid;
  final ValueNotifier<String> codeNotifier;
  final void Function(VoidCallback) onSubmitReady;

  const _ReturnEntryBody({
    required this.bid,
    required this.codeNotifier,
    required this.onSubmitReady,
  });

  @override
  State<_ReturnEntryBody> createState() => _ReturnEntryBodyState();
}

class _ReturnEntryBodyState extends State<_ReturnEntryBody> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.onSubmitReady(_confirm);
  }

  void _confirm() {
    context.read<CancellationBloc>().add(
      ReturnConfirmRequested(widget.bid.id, _controller.text),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    final defaultPinTheme = PinTheme(
      width: 48,
      height: 56,
      textStyle: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(DonyRadius.md),
        border: Border.all(color: cs.primary, width: 2),
      ),
    );
    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: cs.primary, width: 2.5),
    );

    return BlocListener<CancellationBloc, CancellationState>(
      listener: (context, state) {
        if (state is ReturnConfirmed) {
          // Le listener de l'écran parent affiche le snackbar + rafraîchit le bid.
          Navigator.of(context, rootNavigator: true).pop();
        } else if (state is CancellationError) {
          ErrorPresenter.show(context, state.error);
        }
      },
      child: Column(
        children: [
          Pinput(
            controller: _controller,
            length: 6,
            autofocus: true,
            keyboardType: TextInputType.number,
            onChanged: (v) => widget.codeNotifier.value = v,
            defaultPinTheme: defaultPinTheme,
            focusedPinTheme: focusedPinTheme,
          ),
          const SizedBox(height: DonySpacing.md),
          Text(
            'En confirmant, vous déclarez avoir restitué le colis à l\'expéditeur.',
            textAlign: TextAlign.center,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: DonySpacing.xl),
        ],
      ),
    );
  }
}

// Pattern numérique (dd/MM) : pas de données de locale requises.
String _fmtDate(DateTime d) => DateFormat('dd/MM').format(d.toLocal());
