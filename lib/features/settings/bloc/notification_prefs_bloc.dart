import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

part 'notification_prefs_event.dart';
part 'notification_prefs_state.dart';

class NotificationPrefsBloc
    extends Bloc<NotificationPrefsEvent, NotificationPrefsState> {
  final Box _box;

  static const Map<String, bool> _defaults = {
    'push_activity_bids': true,
    'push_activity_negotiations': true,
    'push_messages': true,
    'push_trip_reminder': true,
    'push_promo': false,
    'email_promo': false,
  };

  NotificationPrefsBloc(this._box)
      : super(NotificationPrefsState(
          prefs: {
            for (final e in _defaults.entries)
              e.key: _box.get(
                    'notif_${e.key}',
                    defaultValue: e.value,
                  ) as bool,
          },
        )) {
    on<NotifPrefToggled>(_onToggled);
  }

  void _onToggled(
    NotifPrefToggled event,
    Emitter<NotificationPrefsState> emit,
  ) {
    final updated = Map<String, bool>.from(state.prefs);
    updated[event.key] = !(updated[event.key] ?? false);
    _box.put('notif_${event.key}', updated[event.key]);
    emit(NotificationPrefsState(prefs: updated));
  }
}
