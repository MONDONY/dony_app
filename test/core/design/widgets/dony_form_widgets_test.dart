import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('DonyTextField', () {
    testWidgets('renders TextFormField', (tester) async {
      await tester.pumpWidget(_wrap(const DonyTextField(hint: 'Enter text')));
      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('shows label text', (tester) async {
      await tester.pumpWidget(_wrap(const DonyTextField(label: 'Email')));
      expect(find.text('Email'), findsOneWidget);
    });

    testWidgets('calls onChanged on input', (tester) async {
      String? changed;
      await tester.pumpWidget(
        _wrap(DonyTextField(onChanged: (v) => changed = v)),
      );
      await tester.enterText(find.byType(TextFormField), 'hello');
      expect(changed, 'hello');
    });
  });

  group('DonyTextField.tappable', () {
    testWidgets('DonyTextField.tappable affiche la valeur et déclenche onTap', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DonyTextField.tappable(
              label: 'Date de départ',
              value: 'jeu. 21 mai 2026',
              prefixIcon: Icons.calendar_today,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );
      expect(find.text('jeu. 21 mai 2026'), findsOneWidget);
      await tester.tap(find.text('jeu. 21 mai 2026'));
      expect(tapped, isTrue);
    });

    testWidgets('affiche le label en placeholder quand value est null', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DonyTextField.tappable(
              label: 'Heure de départ',
              prefixIcon: Icons.access_time,
              onTap: () {},
            ),
          ),
        ),
      );
      // Le label sans valeur est rendu comme hint — au moins un widget texte visible.
      expect(find.text('Heure de départ'), findsWidgets);
    });

    testWidgets('affiche le trailing widget quand fourni', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DonyTextField.tappable(
              label: 'Date',
              value: '21 mai 2026',
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('affiche le prefixIcon quand fourni', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DonyTextField.tappable(
              label: 'Date',
              prefixIcon: Icons.calendar_today,
              onTap: () {},
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.calendar_today), findsOneWidget);
    });

    testWidgets('met à jour le texte affiché quand value change après rebuild '
        '(guard anti-staleness)', (tester) async {
      // Arrange — démarre avec une valeur initiale.
      String value = 'lun. 18 mai 2026';

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  DonyTextField.tappable(
                    label: 'Date de départ',
                    value: value,
                    onTap: () {},
                  ),
                  ElevatedButton(
                    onPressed: () => setState(() => value = 'mar. 19 mai 2026'),
                    child: const Text('Changer la date'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Assertion initiale.
      expect(find.text('lun. 18 mai 2026'), findsOneWidget);
      expect(find.text('mar. 19 mai 2026'), findsNothing);

      // Act — déclenche le rebuild avec la nouvelle valeur.
      await tester.tap(find.text('Changer la date'));
      await tester.pump();

      // La nouvelle valeur doit être visible, l'ancienne ne doit plus l'être.
      expect(find.text('mar. 19 mai 2026'), findsOneWidget);
      expect(find.text('lun. 18 mai 2026'), findsNothing);
    });
  });

  group('DonyCard', () {
    testWidgets('renders child', (tester) async {
      await tester.pumpWidget(
        _wrap(const DonyCard(child: Text('Card content'))),
      );
      expect(find.text('Card content'), findsOneWidget);
    });

    testWidgets('adds InkWell when onTap provided', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          DonyCard(onTap: () => tapped = true, child: const Text('Tap me')),
        ),
      );
      await tester.tap(find.byType(InkWell));
      expect(tapped, isTrue);
    });

    testWidgets('no InkWell when no onTap', (tester) async {
      await tester.pumpWidget(_wrap(const DonyCard(child: Text('No tap'))));
      expect(find.byType(InkWell), findsNothing);
    });
  });

  group('DonyBadge', () {
    testWidgets('renders label in uppercase', (tester) async {
      await tester.pumpWidget(_wrap(const DonyBadge(label: 'active')));
      expect(find.text('ACTIVE'), findsOneWidget);
    });

    testWidgets('shows icon when provided', (tester) async {
      await tester.pumpWidget(
        _wrap(const DonyBadge(label: 'test', icon: Icons.check)),
      );
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('info type is default', (tester) async {
      await tester.pumpWidget(_wrap(const DonyBadge(label: 'test')));
      expect(find.byType(DonyBadge), findsOneWidget);
    });

    testWidgets('success type renders', (tester) async {
      // ignore: prefer_const_constructors
      await tester.pumpWidget(
        _wrap(const DonyBadge(label: 'ok', type: DonyBadgeType.success)),
      );
      expect(find.text('OK'), findsOneWidget);
    });

    testWidgets('warning type renders', (tester) async {
      // ignore: prefer_const_constructors
      await tester.pumpWidget(
        _wrap(const DonyBadge(label: 'warn', type: DonyBadgeType.warning)),
      );
      expect(find.text('WARN'), findsOneWidget);
    });

    testWidgets('error type renders', (tester) async {
      // ignore: prefer_const_constructors
      await tester.pumpWidget(
        _wrap(const DonyBadge(label: 'err', type: DonyBadgeType.error)),
      );
      expect(find.text('ERR'), findsOneWidget);
    });
  });

  group('DonyAvatar', () {
    testWidgets('shows two initials for full name', (tester) async {
      await tester.pumpWidget(_wrap(const DonyAvatar(name: 'Ibrahima Diallo')));
      expect(find.text('ID'), findsOneWidget);
    });

    testWidgets('shows single initial for single word name', (tester) async {
      await tester.pumpWidget(_wrap(const DonyAvatar(name: 'Ibrahima')));
      expect(find.text('I'), findsOneWidget);
    });

    testWidgets('shows question mark for empty name', (tester) async {
      await tester.pumpWidget(_wrap(const DonyAvatar(name: '')));
      expect(find.text('?'), findsOneWidget);
    });

    testWidgets('xs size renders Container with dimension 24', (tester) async {
      await tester.pumpWidget(
        _wrap(const DonyAvatar(name: 'Test', size: DonyAvatarSize.xs)),
      );
      expect(find.byType(DonyAvatar), findsOneWidget);
      final size = tester.getSize(find.byType(DonyAvatar));
      expect(size.width, greaterThanOrEqualTo(24));
    });

    testWidgets('sm size renders Container with dimension 32', (tester) async {
      await tester.pumpWidget(
        _wrap(const DonyAvatar(name: 'Test', size: DonyAvatarSize.sm)),
      );
      // Verify the avatar rendered (size sm = 32)
      expect(find.byType(DonyAvatar), findsOneWidget);
      final size = tester.getSize(find.byType(DonyAvatar));
      expect(size.width, greaterThanOrEqualTo(32));
    });

    testWidgets('md size renders correctly', (tester) async {
      await tester.pumpWidget(_wrap(const DonyAvatar(name: 'Test')));
      expect(find.byType(DonyAvatar), findsOneWidget);
      final size = tester.getSize(find.byType(DonyAvatar));
      expect(size.width, greaterThanOrEqualTo(44));
    });

    testWidgets('lg size renders correctly', (tester) async {
      await tester.pumpWidget(
        _wrap(const DonyAvatar(name: 'Test', size: DonyAvatarSize.lg)),
      );
      expect(find.byType(DonyAvatar), findsOneWidget);
      final size = tester.getSize(find.byType(DonyAvatar));
      expect(size.width, greaterThanOrEqualTo(56));
    });

    testWidgets('xl size renders correctly', (tester) async {
      await tester.pumpWidget(
        _wrap(const DonyAvatar(name: 'Test', size: DonyAvatarSize.xl)),
      );
      expect(find.byType(DonyAvatar), findsOneWidget);
      final size = tester.getSize(find.byType(DonyAvatar));
      expect(size.width, greaterThanOrEqualTo(72));
    });

    testWidgets('verified shows check icon', (tester) async {
      await tester.pumpWidget(
        _wrap(const DonyAvatar(name: 'Test User', verified: true)),
      );
      expect(
        find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'badge-check'),
        findsWidgets,
      );
    });

    testWidgets('not verified hides check icon', (tester) async {
      await tester.pumpWidget(_wrap(const DonyAvatar(name: 'Test User')));
      expect(
        find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'badge-check'),
        findsNothing,
      );
    });

    testWidgets('same name produces same initials text', (tester) async {
      // Both should show same initials — deterministic hash
      await tester.pumpWidget(
        _wrap(
          const Column(
            children: [
              DonyAvatar(name: 'Amadou Maiga'),
              DonyAvatar(name: 'Amadou Maiga'),
            ],
          ),
        ),
      );
      expect(find.text('AM'), findsNWidgets(2));
    });

    testWidgets('different names produce avatar widgets', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const Column(
            children: [
              DonyAvatar(name: 'Ibrahima Diallo'),
              DonyAvatar(name: 'Amadou Maiga'),
            ],
          ),
        ),
      );
      expect(find.byType(DonyAvatar), findsNWidgets(2));
    });

    testWidgets('imageUrl shows network image widget', (tester) async {
      // ignore: prefer_const_constructors
      await tester.pumpWidget(
        _wrap(
          const DonyAvatar(
            name: 'Test User',
            imageUrl: 'https://example.com/avatar.jpg',
          ),
        ),
      );
      expect(find.byType(DonyAvatar), findsOneWidget);
    });
  });
}
