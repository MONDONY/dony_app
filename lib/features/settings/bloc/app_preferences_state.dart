part of 'app_preferences_bloc.dart';

class AppPreferencesState extends Equatable {
  final UserPreferencesModel preferences;

  const AppPreferencesState({required this.preferences});

  @override
  List<Object?> get props => [preferences];
}
