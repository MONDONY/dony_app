import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/tracking/bloc/suivi_cubit.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Numéro de suivi demandé au voyageur à la remise du colis (étape DEPART),
/// avant la photo (FLUTTER-BC). Seul l'expéditeur possède ce numéro : le
/// saisir prouve que le voyageur tient le bon colis. Rend le numéro validé,
/// `null` si la feuille est fermée.
///
/// [check] compare le numéro au colis auprès du serveur. Hors ligne, il rend
/// [TrackingNumberCheck.unverified] : la saisie est gardée et le serveur la
/// vérifie à la réception de l'étape.
Future<String?> showSuiviTrackingNumberSheet(
  BuildContext context, {
  required String parcelLabel,
  required Future<TrackingNumberCheck> Function(String number) check,
}) {
  final l = context.l10n;
  return DonyBottomSheet.show<String>(
    context,
    title: l.suiviTrackingNumberTitle,
    child: _TrackingNumberForm(parcelLabel: parcelLabel, check: check),
  );
}

class _TrackingNumberForm extends StatefulWidget {
  const _TrackingNumberForm({required this.parcelLabel, required this.check});

  final String parcelLabel;
  final Future<TrackingNumberCheck> Function(String number) check;

  @override
  State<_TrackingNumberForm> createState() => _TrackingNumberFormState();
}

class _TrackingNumberFormState extends State<_TrackingNumberForm> {
  final _controller = TextEditingController();
  final _error = ValueNotifier<String?>(null);
  final _checking = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _controller.dispose();
    _error.dispose();
    _checking.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = context.l10n;
    final number = _controller.text.trim().toUpperCase();
    if (number.isEmpty) {
      _error.value = l.suiviTrackingNumberRequired;
      return;
    }
    _error.value = null;
    _checking.value = true;
    final result = await widget.check(number);
    if (!mounted) return;
    _checking.value = false;
    if (result == TrackingNumberCheck.wrong) {
      _error.value = l.suiviTrackingNumberWrong;
      return;
    }
    Navigator.of(context, rootNavigator: true).pop(number);
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l.suiviTrackingNumberBody(widget.parcelLabel),
          style: tt.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: DonySpacing.base),
        ValueListenableBuilder<String?>(
          valueListenable: _error,
          builder: (context, error, _) => DonyTextField(
            key: const Key('suivi-tracking-number-field'),
            controller: _controller,
            label: l.suiviTrackingNumberLabel,
            autofocus: true,
            errorText: error,
            textInputAction: TextInputAction.done,
            onChanged: (_) {
              if (_error.value != null) _error.value = null;
            },
            onSubmitted: (_) => _submit(),
          ),
        ),
        const SizedBox(height: DonySpacing.base),
        ValueListenableBuilder<bool>(
          valueListenable: _checking,
          builder: (context, checking, _) => DonyButton(
            key: const Key('suivi-tracking-number-continue'),
            label: l.suiviTrackingNumberContinue,
            iconAsset: 'camera',
            isLoading: checking,
            onPressed: checking ? null : _submit,
          ),
        ),
      ],
    );
  }
}
