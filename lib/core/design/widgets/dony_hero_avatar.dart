import 'package:flutter/material.dart';

class DonyHeroAvatar extends StatelessWidget {
  const DonyHeroAvatar({
    super.key,
    required this.emoji,
    this.size = 88,
  });

  final String emoji;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      constraints: BoxConstraints(maxWidth: size, maxHeight: size),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cs.primaryContainer, const Color(0xFFDCEFE3)],
        ),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.15),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -8),
            spreadRadius: -8,
          ),
        ],
      ),
      child: Center(
        child: Text(emoji, style: TextStyle(fontSize: size * 0.45)),
      ),
    );
  }
}
