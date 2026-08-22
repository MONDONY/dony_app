import 'package:dony/features/auth/bloc/auth_state.dart';

/// Décide quand les blocs *scopés compte* — `BusinessPrefsBloc`,
/// `StripeAccountBloc` — doivent être réinitialisés.
///
/// Les deux sont des `lazySingleton` GetIt : `AuthBloc` ne les recrée
/// jamais. `AuthBloc._clearHiveAccountData()` vide bien la case Hive dont
/// `BusinessPrefsBloc` dérive son état, mais ne touche à aucun des deux
/// blocs eux-mêmes — sans ce garde, ils continueraient de porter le pays et
/// le statut Stripe Connect du compte précédent (régression trouvée en revue
/// finale du lot 2 : `nextStep` routait alors un compte tout neuf comme si
/// son onboarding était déjà avancé).
///
/// Vit ici plutôt que dans `AuthBloc` : aucun bloc du projet n'importe
/// `core/di/injection.dart` pour dispatcher vers un autre bloc (grep vérifié
/// sur `lib/features/*/bloc/`), cette coordination reste toujours au niveau
/// widget — `app.dart`, comme `GuestAccessGuard`/`FavoriteIdsCubit`,
/// `ActiveRoleCubit.syncWithRoles`, `PrivacySettingsRepository` juste
/// au-dessus dans le même `BlocListener<AuthBloc>`. Extraite en garde pure
/// et testée isolément plutôt qu'inline dans `app.dart`, pour la même raison
/// que `GuestAccessGuard.isFreshGuestSession` : un mauvais état dans la
/// chaîne de `if`/`else if` du listener ne doit pas pouvoir passer inaperçu.
abstract final class AccountResetGuard {
  /// `true` exactement dans les états qui suivent un appel à
  /// `AuthBloc._clearHiveAccountData()` :
  /// - [AuthNewAccountAuthenticated] — nouvelle inscription (téléphone ou
  ///   email) ;
  /// - [AuthAccountDeleted] — suppression de compte ;
  /// - [AuthInitial] — déconnexion ou changement de compte.
  ///
  /// [AuthInitial] est aussi l'état initial d'`AuthBloc` avant tout
  /// dispatch, et celui émis pour une session Firebase valide mais sans
  /// compte serveur (`AuthCheckRequested` → 404) : ni l'un ni l'autre
  /// n'appelle `_clearHiveAccountData()`, mais y réagir quand même est sans
  /// risque — le reset relit `_box` (`BusinessPrefsBloc`) ou revient à
  /// `StripeAccountInitial` (`StripeAccountBloc`), deux opérations
  /// idempotentes qui ne changent rien tant que la case Hive n'a pas
  /// vraiment bougé.
  static bool shouldResetAccountScopedBlocs(AuthState state) =>
      state is AuthNewAccountAuthenticated ||
      state is AuthAccountDeleted ||
      state is AuthInitial;
}
