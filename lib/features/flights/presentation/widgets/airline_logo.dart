import 'package:cached_network_image/cached_network_image.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

/// Logo rond d'une compagnie. L'URL vient du back (`logoUrl`) ; sans elle, ou
/// tant que l'image n'est pas chargée, une pastille porte le code IATA.
class AirlineLogo extends StatelessWidget {
  const AirlineLogo({
    super.key,
    required this.code,
    this.logoUrl,
    this.name,
    this.size = 32,
  });

  final String? code;
  final String? logoUrl;

  /// Nom lu par le lecteur d'écran.
  final String? name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        shape: BoxShape.circle,
        border: Border.all(color: cs.outline),
      ),
      child: Text(
        code ?? '',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: cs.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    final url = logoUrl;
    final Widget logo = url == null || url.isEmpty
        ? fallback
        : Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: cs.surface,
              shape: BoxShape.circle,
              border: Border.all(color: cs.outline),
            ),
            clipBehavior: Clip.antiAlias,
            padding: const EdgeInsets.all(DonySpacing.xxs),
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.contain,
              placeholder: (_, _) => fallback,
              errorWidget: (_, _, _) => fallback,
            ),
          );
    return Semantics(
      label: name ?? code,
      image: true,
      excludeSemantics: true,
      child: logo,
    );
  }
}
