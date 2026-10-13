import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Petits éléments communs aux écrans de billets, dessinés comme la maquette
/// de l'onglet (bouton rond, case arrondie, sélecteur en pilule, bouton
/// flottant noir) plutôt que les contrôles Material bruts.

/// Style de la barre d'état des écrans de billets.
///
/// Les écrans de l'onglet n'ont pas d'`AppBar` : sans région annotée, Flutter
/// ne touche plus à la barre d'état et garde le dernier style posé. Après
/// l'attente ou le choix de ville (fond nuit, icônes claires), les résultats
/// restaient donc avec des icônes blanches sur fond clair. Chaque écran pose
/// son style : celui du thème ([AppBarTheme.systemOverlayStyle], icônes
/// sombres en clair, claires en sombre), ou des icônes claires sur le fond
/// nuit ([night]). `statusBarBrightness` sert à iOS, l'autre à Android.
abstract final class FlightStatusBar {
  /// Style d'un écran au fond du thème.
  static SystemUiOverlayStyle of(BuildContext context) {
    final theme = Theme.of(context);
    final light = theme.brightness == Brightness.light;
    final base =
        theme.appBarTheme.systemOverlayStyle ??
        (light ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light);
    return base.copyWith(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: light ? Brightness.dark : Brightness.light,
      statusBarBrightness: light ? Brightness.light : Brightness.dark,
    );
  }

  /// Style d'un écran au fond nuit, quel que soit le thème.
  static SystemUiOverlayStyle night(BuildContext context) =>
      of(context).copyWith(
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      );
}

/// Bouton rond blanc posé sur le fond (cloche, retour). Zone tappable de
/// 44 points, pastille visible de [size].
class FlightRoundButton extends StatelessWidget {
  const FlightRoundButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.iconColor,
    this.size = 38,
  });

  /// Nom de l'icône SVG (`assets/icons/`).
  final String icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? iconColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: onPressed != null,
        label: tooltip,
        excludeSemantics: true,
        child: DonyPressable(
          onTap: onPressed ?? () {},
          child: SizedBox.square(
            dimension: kDonyMinTapTarget,
            child: Center(
              child: AnimatedOpacity(
                duration: DonyDuration.micro,
                opacity: onPressed == null ? 0.4 : 1,
                child: Container(
                  width: size,
                  height: size,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: cs.surface,
                    shape: BoxShape.circle,
                    boxShadow: DonyShadow.sm,
                  ),
                  child: DonyIcon(
                    icon,
                    size: 20,
                    color: iconColor ?? cs.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Case arrondie de 22 points : pleine en bleu avec une coche quand elle est
/// cochée, simple contour sinon.
class FlightCheckBox extends StatelessWidget {
  const FlightCheckBox({super.key, required this.value});

  final bool value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: DonyDuration.micro,
      curve: DonyCurve.easeOut,
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: value ? cs.primary : cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.sm - 1),
        border: Border.all(color: value ? cs.primary : cs.outline, width: 1.6),
      ),
      child: AnimatedScale(
        duration: DonyDuration.micro,
        curve: DonyCurve.easeOut,
        scale: value ? 1 : 0.25,
        child: AnimatedOpacity(
          duration: DonyDuration.micro,
          opacity: value ? 1 : 0,
          child: DonyIcon('check', size: 14, color: cs.onPrimary),
        ),
      ),
    );
  }
}

/// Ligne cochable : la case, puis [label] ou [child]. Toute la ligne est
/// tappable (44 points de haut au moins).
class FlightCheckRow extends StatelessWidget {
  const FlightCheckRow({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.child,
  }) : assert(label != null || child != null, 'label ou child');

  final bool value;
  final ValueChanged<bool> onChanged;
  final String? label;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      checked: value,
      inMutuallyExclusiveGroup: false,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(DonyRadius.sm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kDonyMinTapTarget),
          child: Row(
            children: [
              FlightCheckBox(value: value),
              const SizedBox(width: DonySpacing.md),
              Expanded(
                child:
                    child ??
                    Text(
                      label!,
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sélecteur « Aller-retour / Aller simple » : pilule grise, segment actif
/// blanc au texte bleu, qui glisse d'un choix à l'autre.
class FlightTripTypeSwitch extends StatelessWidget {
  const FlightTripTypeSwitch({
    super.key,
    required this.roundTrip,
    required this.onChanged,
    this.keyPrefix = 'flights-trip',
  });

  final bool roundTrip;
  final ValueChanged<bool> onChanged;

  /// Préfixe des clés des deux segments (`<prefix>-roundtrip`, `-oneway`).
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;

    Widget segment(bool value, String label, String key) {
      final selected = value == roundTrip;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          child: GestureDetector(
            key: Key('$keyPrefix-$key'),
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(value),
            child: Center(
              child: AnimatedDefaultTextStyle(
                duration: DonyDuration.micro,
                style: (tt.labelLarge ?? const TextStyle()).copyWith(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? cs.primary : cs.onSurfaceVariant,
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      height: kDonyMinTapTarget,
      padding: const EdgeInsets.all(DonySpacing.xs),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: DonyDuration.base,
            curve: DonyCurve.easeOut,
            alignment: roundTrip
                ? AlignmentDirectional.centerStart
                : AlignmentDirectional.centerEnd,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(DonyRadius.full),
                  boxShadow: DonyShadow.xs,
                ),
              ),
            ),
          ),
          Row(
            children: [
              segment(true, l.flightsRoundTrip, 'roundtrip'),
              segment(false, l.flightsOneWay, 'oneway'),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bouton flottant en pilule noire (« Alerte prix », « Nouvelle alerte »).
class FlightPillButton extends StatelessWidget {
  const FlightPillButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final String icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      child: DonyPressable(
        onTap: onPressed,
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: DonySpacing.base),
          decoration: BoxDecoration(
            color: cs.inverseSurface,
            borderRadius: BorderRadius.circular(DonyRadius.full),
            boxShadow: [
              BoxShadow(
                color: cs.inverseSurface.withValues(alpha: 0.45),
                blurRadius: 24,
                spreadRadius: -10,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DonyIcon(icon, size: 16, color: cs.onInverseSurface),
              const SizedBox(width: DonySpacing.sm),
              Text(
                label,
                style: tt.labelLarge?.copyWith(
                  fontSize: 13,
                  color: cs.onInverseSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Interrupteur Yadony : piste en pilule, pastille blanche qui glisse.
class FlightToggle extends StatelessWidget {
  const FlightToggle({
    super.key,
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      toggled: value,
      label: semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: SizedBox(
          width: 56,
          height: kDonyMinTapTarget,
          child: Center(
            child: AnimatedContainer(
              duration: DonyDuration.base,
              curve: DonyCurve.easeOut,
              width: 46,
              height: 28,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: value ? cs.primary : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(DonyRadius.full),
                border: Border.all(color: value ? cs.primary : cs.outline),
              ),
              child: AnimatedAlign(
                duration: DonyDuration.base,
                curve: DonyCurve.easeOut,
                alignment: value
                    ? AlignmentDirectional.centerEnd
                    : AlignmentDirectional.centerStart,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: cs.surface,
                    shape: BoxShape.circle,
                    boxShadow: DonyShadow.xs,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Trait pointillé horizontal (pied des cartes d'offre).
class FlightDashedLine extends StatelessWidget {
  const FlightDashedLine({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 1),
      painter: _DashPainter(color ?? Theme.of(context).colorScheme.outline),
    );
  }
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dash = 4.0;
    const gap = 3.0;
    for (var x = 0.0; x < size.width; x += dash + gap) {
      canvas.drawLine(Offset(x, 0), Offset(x + dash, 0), paint);
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}

/// Titre de section en Hanken Grotesk extra-gras (« Vos recherches »,
/// « Essayez plutôt »), avec une action à droite.
class FlightSectionTitle extends StatelessWidget {
  const FlightSectionTitle({
    super.key,
    required this.title,
    this.action,
    this.onAction,
    this.actionKey,
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;
  final Key? actionKey;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: tt.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        if (action != null)
          InkWell(
            key: actionKey,
            onTap: onAction,
            borderRadius: BorderRadius.circular(DonyRadius.sm),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: kDonyMinTapTarget,
                minWidth: kDonyMinTapTarget,
              ),
              child: Center(
                child: Text(
                  action!,
                  style: tt.bodySmall?.copyWith(
                    fontSize: 12.5,
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
