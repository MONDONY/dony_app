import 'package:dony/features/subscriptions/presentation/widgets/subscribe_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host({
    required bool subscribed,
    required bool pushEnabled,
    VoidCallback? onSubscribe,
    VoidCallback? onUnsubscribe,
    ValueChanged<bool>? onTogglePush,
  }) => MaterialApp(
    home: Scaffold(
      body: SubscribeBar(
        subscribed: subscribed,
        pushEnabled: pushEnabled,
        onSubscribe: onSubscribe ?? () {},
        onUnsubscribe: onUnsubscribe ?? () {},
        onTogglePush: onTogglePush ?? (_) {},
      ),
    ),
  );

  testWidgets('non abonné → dit ce que l\'abonnement déclenche', (
    tester,
  ) async {
    await tester.pumpWidget(host(subscribed: false, pushEnabled: false));
    expect(
      find.text('Vous serez prévenu de chacun de ses nouveaux trajets.'),
      findsOneWidget,
    );
    expect(find.text("S'abonner"), findsOneWidget);
  });

  testWidgets('abonné sans push → dit que la notification reste', (
    tester,
  ) async {
    await tester.pumpWidget(host(subscribed: true, pushEnabled: false));
    // Le point central du redesign : la cloche coupe le push, pas la
    // notification, que le serveur inscrit dans tous les cas.
    expect(
      find.textContaining(
        'ses trajets arriveront seulement dans vos notifications',
      ),
      findsOneWidget,
    );
    expect(find.text('Abonné ✓'), findsOneWidget);
    expect(find.text('Push'), findsOneWidget);
  });

  testWidgets('abonné avec push → état annoncé', (tester) async {
    await tester.pumpWidget(host(subscribed: true, pushEnabled: true));
    expect(
      find.textContaining('Alertes push activées'),
      findsOneWidget,
    );
  });

  testWidgets('tap sur S\'abonner déclenche le rappel', (tester) async {
    var appele = false;
    await tester.pumpWidget(
      host(
        subscribed: false,
        pushEnabled: false,
        onSubscribe: () => appele = true,
      ),
    );
    await tester.tap(find.text("S'abonner"));
    expect(appele, isTrue);
  });

  testWidgets('la bascule Push inverse l\'état courant', (tester) async {
    bool? recu;
    await tester.pumpWidget(
      host(
        subscribed: true,
        pushEnabled: false,
        onTogglePush: (v) => recu = v,
      ),
    );
    await tester.tap(find.text('Push'));
    expect(recu, isTrue);
  });

  testWidgets('se désabonner passe par une confirmation', (tester) async {
    var desabonne = false;
    await tester.pumpWidget(
      host(
        subscribed: true,
        pushEnabled: true,
        onUnsubscribe: () => desabonne = true,
      ),
    );

    await tester.tap(find.text('Abonné ✓'));
    await tester.pumpAndSettle();
    expect(find.text('Se désabonner ?'), findsOneWidget);
    expect(desabonne, isFalse);

    await tester.tap(find.text('Se désabonner'));
    await tester.pumpAndSettle();
    expect(desabonne, isTrue);
  });
}
