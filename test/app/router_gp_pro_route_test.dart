import 'package:dony/app/router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Écran GP Pro : route absolue hors shell, ouverte par le menu Moi, les
/// notifications GP_PRO_* et le lien `yadony://profile/gp-pro`.
void main() {
  // PosthogObserver (observers du routeur) lit WidgetsBinding.instance.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('/profile/gp-pro est une route de premier niveau résolue', () {
    final routes = appRouter.configuration.routes.whereType<GoRoute>();
    expect(routes.where((r) => r.path == '/profile/gp-pro'), hasLength(1));

    final match = appRouter.configuration.findMatch(
      Uri.parse('/profile/gp-pro'),
    );
    expect(match.isNotEmpty, isTrue);
    expect(match.uri.path, '/profile/gp-pro');
    expect((match.matches.last.route as GoRoute).path, '/profile/gp-pro');
  });
}
