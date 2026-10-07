import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/get_it_safe.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/firebase_session_probe.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/bloc/active_role_cubit.dart';
import 'package:dony/features/auth/presentation/widgets/auth_required_sheet.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Ce que l'utilisateur veut publier depuis la feuille « + Publier ».
enum HomePublishChoice {
  parcel('/parcels/send-intro', 'parcel'),
  trip('/trips/publish-intro', 'trip');

  const HomePublishChoice(this.route, this.analyticsValue);

  /// Intro existante (conditions + responsabilités) avant la publication.
  final String route;

  /// Valeur de la propriété `choice` de `home_publish_tapped`.
  final String analyticsValue;
}

/// Ordre des choix selon le rôle actif : le parcours du rôle en premier,
/// l'autre toujours proposé juste dessous.
List<HomePublishChoice> homePublishChoicesFor(ActiveRole role) =>
    role == ActiveRole.traveler
    ? const [HomePublishChoice.trip, HomePublishChoice.parcel]
    : const [HomePublishChoice.parcel, HomePublishChoice.trip];

/// Bouton rond « + Publier » de la rangée du haut de l'accueil, posé entre la
/// barre de recherche et la cloche (FLUTTER-B8).
///
/// Même gabarit et même garde-invité que la cloche : un invité tombe sur
/// [AuthRequiredSheet]. Il ne vit QUE dans cette rangée : le bouton flottant
/// « Publier un colis » posé sur la carte au-dessus de la feuille de
/// résultats a été retiré à la demande du propriétaire (#440, revert #442),
/// il ne doit pas revenir.
class HomePublishButton extends StatelessWidget {
  const HomePublishButton({super.key, this.size = 48});

  /// Diamètre du cercle : 48 comme la cloche, 44 sur petit écran.
  final double size;

  String _roleValue(ActiveRole role) =>
      role == ActiveRole.traveler ? 'traveler' : 'sender';

  Future<void> _onTap(BuildContext context) async {
    // Session Firebase, comme la cloche (FLUTTER-7X) : un profil pas encore
    // chargé ne doit pas renvoyer un inscrit vers « Connexion requise ».
    if (!getIt<FirebaseSessionProbe>().hasRealSession) {
      unawaited(AuthRequiredSheet.show(context));
      return;
    }
    final role = context.read<ActiveRoleCubit>().state;
    final analytics = getItSafe<AnalyticsService>();
    unawaited(
      analytics?.logEvent(
        AnalyticsEvents.homePublishSheetOpened,
        properties: {'active_role': _roleValue(role)},
      ),
    );
    final choice = await HomePublishSheet.show(context, role: role);
    if (choice == null || !context.mounted) return;
    unawaited(
      analytics?.logEvent(
        AnalyticsEvents.homePublishTapped,
        properties: {
          'choice': choice.analyticsValue,
          'active_role': _roleValue(role),
        },
      ),
    );
    unawaited(context.push<Object?>(choice.route));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    return Semantics(
      button: true,
      label: l.homePublishButtonSemantics,
      excludeSemantics: true,
      child: Tooltip(
        message: l.homePublishButtonTooltip,
        excludeFromSemantics: true,
        child: GestureDetector(
          key: const Key('home-publish-button'),
          onTap: () => _onTap(context),
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: cs.surface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              // Teinte primaire : se distingue de la cloche (gris au repos)
              // sans changer de surface ni d'ombre.
              child: DonyIcon('plus', color: cs.primary),
            ),
          ),
        ),
      ),
    );
  }
}

/// Feuille à deux choix ouverte par [HomePublishButton].
///
/// Montée sur le navigateur racine (`DonyBottomSheet.show`) : elle ne voit pas
/// le `GoRouter` de l'onglet et rend son choix à l'appelant, qui trace puis
/// pousse (même contrat que `ActivitesMenuSheet`). Pas de `DonyButton` : les
/// deux lignes sont elles-mêmes les actions.
abstract final class HomePublishSheet {
  static Future<HomePublishChoice?> show(
    BuildContext context, {
    required ActiveRole role,
  }) {
    return DonyBottomSheet.show<HomePublishChoice>(
      context,
      title: context.l10n.homePublishSheetTitle,
      child: _HomePublishSheetContent(choices: homePublishChoicesFor(role)),
    );
  }
}

class _HomePublishSheetContent extends StatelessWidget {
  const _HomePublishSheetContent({required this.choices});

  final List<HomePublishChoice> choices;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, choice) in choices.indexed)
          switch (choice) {
            // Couleurs et icônes des tuiles du hub Activités : terracotta et
            // colis pour l'envoi, bleu et avion pour le trajet.
            HomePublishChoice.parcel => _ChoiceTile(
              itemKey: const Key('home-publish-choice-parcel'),
              iconAsset: 'package',
              color: cs.secondary,
              label: l.homePublishSendParcel,
              subtitle: l.homePublishSendParcelSubtitle,
              choice: choice,
              showDivider: i < choices.length - 1,
            ),
            HomePublishChoice.trip => _ChoiceTile(
              itemKey: const Key('home-publish-choice-trip'),
              iconAsset: 'plane',
              color: cs.primary,
              label: l.homePublishTrip,
              subtitle: l.homePublishTripSubtitle,
              choice: choice,
              showDivider: i < choices.length - 1,
            ),
          },
      ],
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.itemKey,
    required this.iconAsset,
    required this.color,
    required this.label,
    required this.subtitle,
    required this.choice,
    required this.showDivider,
  });

  final Key itemKey;
  final String iconAsset;
  final Color color;
  final String label;
  final String subtitle;
  final HomePublishChoice choice;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return DonyListTile(
      key: itemKey,
      iconAsset: iconAsset,
      iconColor: color,
      iconBgColor: color.withValues(alpha: 0.12),
      label: label,
      subtitle: subtitle,
      showDivider: showDivider,
      onTap: () => Navigator.of(context).pop(choice),
    );
  }
}
