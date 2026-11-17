import 'package:flutter/material.dart';

/// Logo Yadony en rond : photo de profil de « Support Yadony » dans la liste
/// des messages et l'en-tête de la discussion.
class SupportYadonyLogo extends StatelessWidget {
  const SupportYadonyLogo({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: cs.outlineVariant),
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/logos/yadony_mark_128.png',
          key: const Key('support-yadony-logo'),
          width: size,
          height: size,
          fit: BoxFit.cover,
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}
