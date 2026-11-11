import 'package:dony/app/router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Écran Informations fiscales (DAC7) : route absolue hors shell, ouverte par
/// la bannière du Profil, les notifications TAX_INFO_REQUEST / TAX_STATEMENT
/// et le lien `yadony://profile/tax-info`.
void main() {
  // PosthogObserver (observers du routeur) lit WidgetsBinding.instance.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('/profile/tax-info est une route de premier niveau résolue', () {
    final routes = appRouter.configuration.routes.whereType<GoRoute>();
    expect(routes.where((r) => r.path == '/profile/tax-info'), hasLength(1));

    final match = appRouter.configuration.findMatch(
      Uri.parse('/profile/tax-info'),
    );
    expect(match.isNotEmpty, isTrue);
    expect(match.uri.path, '/profile/tax-info');
    expect((match.matches.last.route as GoRoute).path, '/profile/tax-info');
  });
}
