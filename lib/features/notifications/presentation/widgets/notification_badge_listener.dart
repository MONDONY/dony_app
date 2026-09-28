import 'dart:async';

import 'package:dony/core/services/app_badge_service.dart';
import 'package:dony/features/notifications/bloc/notification_bloc.dart';
import 'package:dony/features/notifications/bloc/notification_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Reporte sur la pastille de l'icône chaque changement du compteur de
/// notifications non lues tenu par [NotificationBloc].
///
/// Sans lui, la pastille n'était relue qu'au démarrage, à la réception d'une
/// push et au retour au premier plan. Lire ses notifications puis quitter
/// l'application laissait donc l'ancien nombre sur l'icône, corrigé seulement
/// au prochain aller-retour dans l'application.
class NotificationBadgeListener
    extends BlocListener<NotificationBloc, NotificationState> {
  NotificationBadgeListener({
    super.key,
    required AppBadgeService badge,
    super.child,
  }) : super(
         listenWhen: (_, current) => current is NotificationLoaded,
         listener: (_, state) => unawaited(
           badge.setNotifications((state as NotificationLoaded).unreadCount),
         ),
       );
}
