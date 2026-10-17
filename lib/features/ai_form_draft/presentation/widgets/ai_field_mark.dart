import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/ai_form_draft/bloc/ai_filled_fields_cubit.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Marque « IA » d'un champ rempli par l'IA ([fields] : clés du brouillon).
class AiFieldMark extends StatelessWidget {
  /// Marque à droite d'un libellé de champ.
  const AiFieldMark({super.key, required this.fields, required this.child})
    : _overlay = false;

  /// Marque posée en haut à droite d'un champ.
  const AiFieldMark.overlay({
    super.key,
    required this.fields,
    required this.child,
  }) : _overlay = true;

  final List<String> fields;
  final Widget child;
  final bool _overlay;

  bool _marked(Set<String> filled) => fields.any(filled.contains);

  @override
  Widget build(BuildContext context) {
    final AiFilledFieldsCubit cubit;
    try {
      cubit = context.read<AiFilledFieldsCubit>();
    } on ProviderNotFoundException {
      return child;
    }
    return BlocBuilder<AiFilledFieldsCubit, Set<String>>(
      bloc: cubit,
      buildWhen: (a, b) => _marked(a) != _marked(b),
      builder: (context, filled) {
        final marked = _marked(filled);
        if (_overlay) {
          return Stack(
            clipBehavior: Clip.none,
            children: [
              child,
              if (marked) const Positioned(top: 6, right: 8, child: _AiBadge()),
            ],
          );
        }
        return Row(
          children: [
            Flexible(child: child),
            if (marked) ...[
              const SizedBox(width: DonySpacing.xs),
              const _AiBadge(),
            ],
          ],
        );
      },
    );
  }
}

class _AiBadge extends StatelessWidget {
  const _AiBadge();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      key: const Key('ai-field-mark'),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cs.primary,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Text(
        context.l10n.assistantBadge,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: cs.onPrimary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
