import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/recipient_change/recipient_change_cubit.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/recipients/data/phone_validation.dart';
import 'package:dony/features/recipients/presentation/widgets/recipient_picker_sheet.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Issue de la feuille « Modifier le destinataire ».
enum RecipientChangeResult {
  /// Nouveau numéro : lien de suivi et code de retrait renouvelés.
  recipientChanged,

  /// Même numéro : seul le nom a changé.
  nameUpdated,

  /// 409 : le colis a été remis entre-temps.
  conflict,
}

/// Longueur maximale du nom, alignée sur le serveur (`@Size(max = 100)`).
const int kRecipientNameMaxLength = 100;

/// Ouvre la feuille « Modifier le destinataire » puis, si elle aboutit,
/// recharge le détail d'envoi ([BidBloc] de l'écran, s'il est là) et confirme
/// d'une snackbar. Un 409 recharge aussi : le statut a changé.
Future<void> openRecipientChangeSheet(
  BuildContext context,
  BidModel bid,
) async {
  BidBloc? bidBloc;
  try {
    bidBloc = context.read<BidBloc>();
  } on ProviderNotFoundException {
    bidBloc = null;
  }
  final result = await RecipientChangeSheet.show(context, bid: bid);
  if (result == null || !context.mounted) return;
  bidBloc?.add(BidDetailRequested(bid.id));
  final l = context.l10n;
  switch (result) {
    case RecipientChangeResult.recipientChanged:
      DonySnackbar.show(
        context,
        message: l.recipientChangeSuccess,
        type: DonySnackbarType.success,
      );
    case RecipientChangeResult.nameUpdated:
      DonySnackbar.show(
        context,
        message: l.recipientChangeNameUpdated,
        type: DonySnackbarType.success,
      );
    case RecipientChangeResult.conflict:
      DonySnackbar.show(
        context,
        message: l.recipientChangeConflict,
        type: DonySnackbarType.error,
      );
  }
}

/// Contenu de la feuille : nom + téléphone du destinataire pré-remplis, lien
/// vers le carnet, avertissement quand le numéro change. Le bouton
/// « Enregistrer » vit dans le `stickyBottom` et reçoit la soumission par
/// [onSubmitReady] ; sa validité arrive par [canSubmit], que ce `State`
/// possède et dispose (écrit par les écouteurs des champs, pas seulement par
/// un geste).
class RecipientChangeSheet extends StatefulWidget {
  const RecipientChangeSheet({
    super.key,
    required this.bid,
    required this.canSubmit,
    this.onSubmitReady,
  });

  final BidModel bid;
  final ValueNotifier<bool> canSubmit;
  final void Function(VoidCallback)? onSubmitReady;

  static Future<RecipientChangeResult?> show(
    BuildContext context, {
    required BidModel bid,
  }) {
    VoidCallback? submit;
    // Disposé par le State du contenu (voir la doc de la classe).
    final canSubmit = ValueNotifier<bool>(false);
    final l = context.l10n;
    return DonyBottomSheet.show<RecipientChangeResult>(
      context,
      title: l.recipientChangeTitle,
      wrapper: (child) => BlocProvider(
        create: (_) => getIt<RecipientChangeCubit>(),
        child: child,
      ),
      stickyBottom: ValueListenableBuilder<bool>(
        valueListenable: canSubmit,
        builder: (ctx, enabled, _) =>
            BlocBuilder<RecipientChangeCubit, RecipientChangeState>(
              builder: (ctx, state) {
                final loading = state is RecipientChangeSubmitting;
                return DonyButton(
                  label: l.commonSave,
                  isLoading: loading,
                  onPressed: (loading || !enabled)
                      ? null
                      : () => submit?.call(),
                );
              },
            ),
      ),
      child: RecipientChangeSheet(
        bid: bid,
        canSubmit: canSubmit,
        onSubmitReady: (fn) => submit = fn,
      ),
    );
  }

  @override
  State<RecipientChangeSheet> createState() => _RecipientChangeSheetState();
}

class _RecipientChangeSheetState extends State<RecipientChangeSheet> {
  late final TextEditingController _nameCtrl = TextEditingController(
    text: widget.bid.recipientName ?? '',
  );
  late final TextEditingController _phoneCtrl = TextEditingController(
    text: widget.bid.recipientPhone ?? '',
  );
  final FocusNode _phoneFocus = FocusNode();

  /// Le champ téléphone a perdu le focus au moins une fois : l'erreur de
  /// format ne s'affiche qu'à partir de là (validation à la perte de focus).
  final ValueNotifier<bool> _phoneTouched = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    widget.onSubmitReady?.call(_submit);
    _nameCtrl.addListener(_notifyValidity);
    _phoneCtrl.addListener(_notifyValidity);
    _phoneFocus.addListener(_onPhoneFocusChanged);
    _notifyValidity();
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_notifyValidity);
    _phoneCtrl.removeListener(_notifyValidity);
    _phoneFocus.removeListener(_onPhoneFocusChanged);
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _phoneFocus.dispose();
    _phoneTouched.dispose();
    widget.canSubmit.dispose();
    super.dispose();
  }

  void _onPhoneFocusChanged() {
    if (!_phoneFocus.hasFocus) _phoneTouched.value = true;
  }

  bool get _phoneValid =>
      kRecipientPhoneE164.hasMatch(normalizeRecipientPhone(_phoneCtrl.text));

  bool get _phoneChanged =>
      RecipientChangeCubit.isPhoneChanged(widget.bid, _phoneCtrl.text);

  /// Nom renseigné, numéro valide, et quelque chose a changé.
  void _notifyValidity() {
    final name = _nameCtrl.text.trim();
    final nameChanged = name != (widget.bid.recipientName ?? '').trim();
    widget.canSubmit.value =
        name.isNotEmpty &&
        name.length <= kRecipientNameMaxLength &&
        _phoneValid &&
        (nameChanged || _phoneChanged);
  }

  Future<void> _pickFromBook() async {
    final recipient = await RecipientPickerSheet.show(
      context,
      currentPhone: _phoneCtrl.text.trim(),
    );
    if (recipient == null || !mounted) return;
    _nameCtrl.text = recipient.fullName;
    _phoneCtrl.text = recipient.phoneE164;
  }

  void _submit() {
    if (!widget.canSubmit.value) return;
    context.read<RecipientChangeCubit>().submit(
      widget.bid,
      name: _nameCtrl.text,
      phone: _phoneCtrl.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return BlocListener<RecipientChangeCubit, RecipientChangeState>(
      listener: (context, state) {
        switch (state) {
          case RecipientChangeSuccess(:final phoneChanged):
            Navigator.of(context).pop(
              phoneChanged
                  ? RecipientChangeResult.recipientChanged
                  : RecipientChangeResult.nameUpdated,
            );
          case RecipientChangeConflict():
            Navigator.of(context).pop(RecipientChangeResult.conflict);
          case RecipientChangeFailure(:final error):
            ErrorPresenter.show(context, error);
          case RecipientChangeIdle() || RecipientChangeSubmitting():
            break;
        }
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: DonySpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DonyTextField(
              controller: _nameCtrl,
              label: l.bidCreateRecipientNameLabel,
              hint: l.bidCreateRecipientNameHint,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: DonySpacing.md),
            ValueListenableBuilder<bool>(
              valueListenable: _phoneTouched,
              builder: (context, touched, _) => ListenableBuilder(
                listenable: _phoneCtrl,
                builder: (context, _) => DonyTextField(
                  controller: _phoneCtrl,
                  focusNode: _phoneFocus,
                  label: l.bidCreateRecipientPhoneLabel,
                  hint: l.bidCreateRecipientPhoneHint,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  errorText:
                      touched &&
                          _phoneCtrl.text.trim().isNotEmpty &&
                          !_phoneValid
                      ? l.requestCreateRecipientPhoneFormat
                      : null,
                ),
              ),
            ),
            const SizedBox(height: DonySpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _pickFromBook,
                icon: DonyIcon('contact', size: 18, color: cs.primary),
                label: Text(l.recipientChangePickFromBook),
              ),
            ),
            ListenableBuilder(
              listenable: _phoneCtrl,
              builder: (context, _) {
                final show = _phoneCtrl.text.trim().isNotEmpty && _phoneChanged;
                if (!show) return const SizedBox.shrink();
                return Container(
                  margin: const EdgeInsets.only(top: DonySpacing.sm),
                  padding: const EdgeInsets.all(DonySpacing.md),
                  decoration: BoxDecoration(
                    color: cs.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(DonyRadius.md),
                    border: Border.all(
                      color: cs.warning.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DonyIcon('triangle-alert', size: 18, color: cs.warning),
                      const SizedBox(width: DonySpacing.sm),
                      Expanded(
                        child: Text(
                          l.recipientChangePhoneWarning,
                          style: tt.bodySmall?.copyWith(color: cs.onSurface),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
