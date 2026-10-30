import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/presentation/widgets/tool_status_badge.dart';
import 'package:flutter/material.dart';

/// Tuile de la section « À traiter » de la fiche colis (vues expéditeur et
/// voyageur) : couleur primaire, pastille ambre ([ToolStatusTone.news]) qui
/// dit ce qui est attendu, clé `<role>-todo-<tile>`.
///
/// [role] : `sender` ou `traveler` ; [tile] : nom de la tuile. Le corps passe
/// un [onTap] qui ouvre le sheet avec son propre contexte, jamais celui de la
/// tuile : elle disparaît dès que la demande est traitée. [subtitleMaxLines] :
/// 3 pour un résumé qui porte une échéance et doit rester entier.
DonyActionTile todoActionTile(
  BuildContext context, {
  required String role,
  required String tile,
  required String iconName,
  required String label,
  required String? subtitle,
  required String badge,
  required VoidCallback onTap,
  int subtitleMaxLines = 2,
}) => DonyActionTile(
  key: Key('$role-todo-$tile'),
  iconName: iconName,
  label: label,
  subtitle: subtitle,
  subtitleMaxLines: subtitleMaxLines,
  color: Theme.of(context).colorScheme.primary,
  badge: ToolStatusBadge(
    ready: false,
    tone: ToolStatusTone.news,
    label: badge,
    semanticsLabel: badge,
  ),
  onTap: onTap,
);
