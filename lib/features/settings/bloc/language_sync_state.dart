import 'package:equatable/equatable.dart';

/// État de synchronisation de la langue effective avec le compte serveur.
///
/// [synced] est la dernière langue confirmée : déjà égale à
/// `user.preferredLanguage` au moment de l'appel, ou écrite avec succès par
/// [LanguageSyncCubit.sync]. `null` tant qu'aucune synchronisation n'a
/// abouti (démarrage, invité, backend ancien en 404, échec réseau).
class LanguageSyncState extends Equatable {
  const LanguageSyncState({this.synced});

  final String? synced;

  @override
  List<Object?> get props => [synced];
}
