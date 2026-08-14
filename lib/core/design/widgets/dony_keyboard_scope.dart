import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

/// Enveloppe globale qui rend le clavier refermable partout dans l'app.
///
/// Deux mécanismes, montés une seule fois autour du Navigator racine :
///
/// 1. **Tap hors champ** — un tap n'importe où en dehors du champ actif retire
///    le focus. Sans ça, l'utilisateur doit viser un autre champ pour fermer le
///    clavier, et rien ne le laisse simplement « sortir » de la saisie.
/// 2. **Barre « Terminé »** — affichée juste au-dessus du clavier quand le
///    champ actif n'offre aucune touche de validation : pavé numérique iOS
///    (aucune touche « retour ») et champs multilignes (« retour » = saut de
///    ligne). Ce sont exactement les cas où le clavier reste collé à l'écran et
///    masque les champs suivants ou la liste d'autocomplétion.
class DonyKeyboardScope extends StatefulWidget {
  const DonyKeyboardScope({required this.child, super.key});

  final Widget child;

  @override
  State<DonyKeyboardScope> createState() => _DonyKeyboardScopeState();
}

class _DonyKeyboardScopeState extends State<DonyKeyboardScope> {
  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocusChanged);
    super.dispose();
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  static void _dismiss() => FocusManager.instance.primaryFocus?.unfocus();

  /// Le champ actif offre-t-il déjà un moyen de fermer le clavier ?
  ///
  /// On remonte à l'[EditableText] qui porte le focus pour lire son type de
  /// clavier : seul le champ lui-même sait si sa touche « retour » valide la
  /// saisie ou insère un saut de ligne.
  bool _needsDoneBar() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return false;
    final editable = ctx.findAncestorWidgetOfExactType<EditableText>();
    if (editable == null) return false;
    if (editable.maxLines != 1) return true;
    // Comparaison sur la représentation textuelle : `numberWithOptions(decimal:
    // true)` n'est pas égal à `TextInputType.number` (les options entrent dans
    // l'égalité) alors qu'il ouvre le même pavé, sans touche retour.
    final type = editable.keyboardType.toString();
    return type.contains('TextInputType.number') ||
        type.contains('TextInputType.phone') ||
        type.contains('TextInputType.datetime');
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final showBar = inset > 0 && _needsDoneBar();
    return Stack(
      children: [
        GestureDetector(
          // translucent : le tap continue vers les widgets en dessous, on ne
          // vole aucun bouton, on ne fait qu'observer.
          behavior: HitTestBehavior.translucent,
          onTap: _dismiss,
          child: widget.child,
        ),
        if (showBar)
          Positioned(
            left: 0,
            right: 0,
            bottom: inset,
            child: const _KeyboardDoneBar(),
          ),
      ],
    );
  }
}

/// Barre compacte « Terminé » posée au ras du clavier.
class _KeyboardDoneBar extends StatelessWidget {
  const _KeyboardDoneBar();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Material(
      key: const Key('donyKeyboardDoneBar'),
      color: cs.surfaceContainerHighest,
      child: SizedBox(
        height: 44,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Semantics(
              button: true,
              container: true,
              excludeSemantics: true,
              label: 'Masquer le clavier',
              child: InkWell(
                onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DonySpacing.base,
                    vertical: DonySpacing.sm,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.keyboard_hide_rounded,
                        size: 18,
                        color: cs.primary,
                      ),
                      const SizedBox(width: DonySpacing.xs),
                      Text(
                        'Terminé',
                        style: tt.labelLarge?.copyWith(color: cs.primary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
