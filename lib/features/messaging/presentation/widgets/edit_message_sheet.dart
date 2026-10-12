import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/messaging/data/chat_message_validator.dart';
import 'package:dony/features/messaging/presentation/chat_labels.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Feuille « Modifier le message » (FLUTTER-MG). Rend le nouveau texte,
/// validé par [ChatMessageValidator], ou `null` si l'utilisateur renonce.
///
/// Règles bottom sheet du projet : le bouton vit dans `stickyBottom` ; le
/// [TextEditingController] et le notifier du bouton appartiennent au `State`
/// du contenu et y sont disposés. Le contrôleur notifie aussi pendant
/// l'animation de sortie (clavier qui se replie), un `whenComplete` les
/// aurait disposés trop tôt (FLUTTER-18, FLUTTER-1C).
abstract final class EditMessageSheet {
  static Future<String?> show(
    BuildContext context, {
    required String initialText,
  }) {
    final l = context.l10n;
    final submit = ValueNotifier<VoidCallback?>(null);
    return DonyBottomSheet.show<String>(
      context,
      title: l.chatEditSheetTitle,
      subtitle: l.chatEditSheetSubtitle,
      stickyBottom: ValueListenableBuilder<VoidCallback?>(
        valueListenable: submit,
        builder: (_, onSubmit, _) => DonyButton(
          key: const Key('chat-edit-submit'),
          label: l.chatEditSaveButton,
          onPressed: onSubmit,
        ),
      ),
      child: EditMessageForm(initialText: initialText, submit: submit),
    );
  }
}

@visibleForTesting
class EditMessageForm extends StatefulWidget {
  const EditMessageForm({
    super.key,
    required this.initialText,
    required this.submit,
  });

  final String initialText;

  /// Soumission du bouton de la feuille, `null` tant que rien n'a changé.
  /// Possédé (et disposé) par ce `State`.
  final ValueNotifier<VoidCallback?> submit;

  @override
  State<EditMessageForm> createState() => _EditMessageFormState();
}

class _EditMessageFormState extends State<EditMessageForm> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialText,
  );
  final _error = ValueNotifier<String?>(null);
  final _validator = ChatMessageValidator();
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _disposed = true;
    _controller
      ..removeListener(_onChanged)
      ..dispose();
    _error.dispose();
    widget.submit.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (_disposed) return;
    final text = _controller.text.trim();
    final changed = text.isNotEmpty && text != widget.initialText.trim();
    widget.submit.value = changed ? _submit : null;
    if (_error.value != null) _error.value = null;
  }

  void _submit() {
    final result = _validator.validate(_controller.text);
    if (result is ChatValidationBlocked) {
      final message = chatBlockedMessage(
        context.l10n,
        result.reason,
        term: result.term,
      );
      _error.value = message.isEmpty ? null : message;
      return;
    }
    Navigator.of(context).pop((result as ChatValidationOk).text);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ValueListenableBuilder<String?>(
      valueListenable: _error,
      builder: (_, error, _) => DonyTextField(
        key: const Key('chat-edit-field'),
        controller: _controller,
        label: l.chatEditFieldLabel,
        autofocus: true,
        minLines: 1,
        maxLines: 6,
        keyboardType: TextInputType.multiline,
        errorText: error,
      ),
    );
  }
}
