import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pinput/pinput.dart';

/// Saisie d'un code à 6 chiffres reçu par SMS ou par e-mail.
///
/// Remplace six `TextFormField` d'un caractère chacun. Sans indice
/// `oneTimeCode`, le téléphone ne proposait pas le code reçu au-dessus du
/// clavier, et même collé il était tronqué à un chiffre par case :
/// l'utilisateur devait aller le chercher dans Messages, où iOS range les SMS
/// d'expéditeurs inconnus hors de la liste principale (« Filtres ›
/// Transactions »). Les testeurs voyaient la notification mais ne trouvaient
/// plus le SMS.
///
/// [Pinput] porte `AutofillHints.oneTimeCode` par défaut et répartit un code
/// collé sur les six cases.
class OtpCodeField extends StatelessWidget {
  const OtpCodeField({
    super.key,
    required this.controller,
    this.focusNode,
    this.onCompleted,
    this.boxWidth = 48,
    this.boxHeight = 56,
    this.gap = DonySpacing.sm,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;

  /// Appelé quand les six chiffres sont saisis, remplissage auto compris.
  final ValueChanged<String>? onCompleted;

  /// Largeur d'une case. Fixée par l'appelant, jamais mesurée ici : ce champ
  /// vit aussi dans une bottom sheet, où un `LayoutBuilder` casserait le
  /// calcul de hauteur intrinsèque.
  final double boxWidth;
  final double boxHeight;
  final double gap;

  static const length = 6;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final base = PinTheme(
      width: boxWidth,
      height: boxHeight,
      textStyle: tt.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: cs.onSurface,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.md),
        border: Border.all(color: cs.outline),
      ),
    );

    return Pinput(
      length: length,
      controller: controller,
      focusNode: focusNode,
      autofocus: true,
      // Curseur fixe : l'animation de clignotement tourne sans fin, ce qui
      // empêche tout `pumpAndSettle` dans les tests des écrans qui l'hébergent.
      isCursorAnimationEnabled: false,
      // Un code collé depuis un message peut traîner des lettres ou des
      // espaces : seuls les chiffres entrent, comme dans les anciennes cases.
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      separatorBuilder: (_) => SizedBox(width: gap),
      defaultPinTheme: base,
      focusedPinTheme: base.copyDecorationWith(
        border: Border.all(color: cs.primary, width: 2),
      ),
      onCompleted: onCompleted,
    );
  }
}
