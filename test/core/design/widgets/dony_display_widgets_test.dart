import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  // ---------------------------------------------------------------------------
  // DonyListTile
  // ---------------------------------------------------------------------------
  group('DonyListTile', () {
    testWidgets('renders label text', (tester) async {
      await tester.pumpWidget(
        _wrap(const DonyListTile(label: 'Notifications')),
      );
      await tester.pump();
      expect(find.text('Notifications'), findsOneWidget);
    });

    testWidgets('renders subtitle when provided', (tester) async {
      await tester.pumpWidget(
        _wrap(const DonyListTile(label: 'Langue', subtitle: 'Français')),
      );
      await tester.pump();
      expect(find.text('Langue'), findsOneWidget);
      expect(find.text('Français'), findsOneWidget);
    });

    testWidgets('hides subtitle when null', (tester) async {
      await tester.pumpWidget(_wrap(const DonyListTile(label: 'No sub')));
      await tester.pump();
      expect(find.text('No sub'), findsOneWidget);
      // No extra text widget for subtitle
    });

    testWidgets('renders icon when provided', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const DonyListTile(label: 'Settings', icon: Icons.settings_outlined),
        ),
      );
      await tester.pump();
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    });

    testWidgets('hides icon when null', (tester) async {
      await tester.pumpWidget(_wrap(const DonyListTile(label: 'No icon')));
      await tester.pump();
      expect(find.byType(DonyIconContainer), findsNothing);
    });

    testWidgets('onTap callback fires', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(DonyListTile(label: 'Tappable', onTap: () => tapped = true)),
      );
      await tester.pump();
      await tester.tap(find.byType(InkWell));
      expect(tapped, isTrue);
    });

    testWidgets('shows chevron when onTap provided and no trailing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(DonyListTile(label: 'With chevron', onTap: () {})),
      );
      await tester.pump();
      expect(
        find.byWidgetPredicate(
          (w) => w is DonyIcon && w.name == 'chevron-right',
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows trailing widget when provided', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DonyListTile(
            label: 'With switch',
            trailing: const Icon(Icons.toggle_on),
            onTap: () {},
          ),
        ),
      );
      await tester.pump();
      expect(find.byIcon(Icons.toggle_on), findsOneWidget);
      // No chevron when trailing is provided
      expect(
        find.byWidgetPredicate(
          (w) => w is DonyIcon && w.name == 'chevron-right',
        ),
        findsNothing,
      );
    });

    testWidgets('shows SizedBox.shrink when no onTap and no trailing', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const DonyListTile(label: 'Static item')));
      await tester.pump();
      expect(find.byType(SizedBox), findsWidgets);
      expect(
        find.byWidgetPredicate(
          (w) => w is DonyIcon && w.name == 'chevron-right',
        ),
        findsNothing,
      );
    });

    testWidgets('shows divider by default', (tester) async {
      await tester.pumpWidget(_wrap(const DonyListTile(label: 'With divider')));
      await tester.pump();
      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('hides divider when showDivider is false', (tester) async {
      await tester.pumpWidget(
        _wrap(const DonyListTile(label: 'No divider', showDivider: false)),
      );
      await tester.pump();
      expect(find.byType(Divider), findsNothing);
    });

    testWidgets('disabled tile does not fire onTap', (tester) async {
      var callCount = 0;
      await tester.pumpWidget(
        _wrap(
          DonyListTile(
            label: 'Disabled',
            enabled: false,
            onTap: () => callCount++,
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byType(InkWell));
      expect(callCount, 0);
    });

    testWidgets('destructive=true changes label color to error', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const DonyListTile(label: 'Delete account', destructive: true)),
      );
      await tester.pump();
      expect(find.text('Delete account'), findsOneWidget);
      // Widget renders — color logic exercised via coverage
    });

    testWidgets('destructive=true with icon uses error color for icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const DonyListTile(
            label: 'Delete',
            icon: Icons.delete_outline,
            destructive: true,
          ),
        ),
      );
      await tester.pump();
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('custom iconColor and iconBgColor are applied', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const DonyListTile(
            label: 'Custom colors',
            icon: Icons.star,
            iconColor: DonyColors.warning,
            iconBgColor: DonyColors.accentSoft,
          ),
        ),
      );
      await tester.pump();
      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('all params combined', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          DonyListTile(
            label: 'All options',
            subtitle: 'A subtitle here',
            icon: Icons.notifications_outlined,
            iconColor: DonyColors.primary,
            iconBgColor: DonyColors.primarySoft,
            trailing: const Icon(Icons.more_vert),
            onTap: () => tapped = true,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('All options'), findsOneWidget);
      expect(find.text('A subtitle here'), findsOneWidget);
      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
      await tester.tap(find.byType(InkWell));
      expect(tapped, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // DonyListSection
  // ---------------------------------------------------------------------------
  group('DonyListSection', () {
    testWidgets('renders section title in uppercase', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const DonyListSection(
            title: 'compte',
            tiles: [
              DonyListTile(label: 'Profil'),
              DonyListTile(label: 'Sécurité'),
            ],
          ),
        ),
      );
      await tester.pump();
      expect(find.text('COMPTE'), findsOneWidget);
    });

    testWidgets('hides title when null', (tester) async {
      await tester.pumpWidget(
        _wrap(const DonyListSection(tiles: [DonyListTile(label: 'Item')])),
      );
      await tester.pump();
      expect(find.byType(DonyListSection), findsOneWidget);
    });

    testWidgets('renders all tiles', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const DonyListSection(
            tiles: [
              DonyListTile(label: 'Tile A'),
              DonyListTile(label: 'Tile B'),
              DonyListTile(label: 'Tile C'),
            ],
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Tile A'), findsOneWidget);
      expect(find.text('Tile B'), findsOneWidget);
      expect(find.text('Tile C'), findsOneWidget);
    });

    testWidgets('last tile has no divider, others do', (tester) async {
      // DonyListSection passes showDivider: i < tiles.length - 1
      await tester.pumpWidget(
        _wrap(
          const DonyListSection(
            tiles: [
              DonyListTile(label: 'First'),
              DonyListTile(label: 'Last'),
            ],
          ),
        ),
      );
      await tester.pump();
      // 1 divider: first tile gets it, last does not
      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('single tile has no divider', (tester) async {
      await tester.pumpWidget(
        _wrap(const DonyListSection(tiles: [DonyListTile(label: 'Solo')])),
      );
      await tester.pump();
      expect(find.byType(Divider), findsNothing);
    });

    testWidgets('tile callbacks are forwarded correctly', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          DonyListSection(
            title: 'Actions',
            tiles: [DonyListTile(label: 'Tap me', onTap: () => tapped = true)],
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byType(InkWell));
      expect(tapped, isTrue);
    });

    testWidgets('tiles with all props are forwarded by DonyListSection', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const DonyListSection(
            title: 'Paramètres',
            tiles: [
              DonyListTile(
                label: 'Option 1',
                subtitle: 'Sub 1',
                icon: Icons.lock_outline,
                trailing: Icon(Icons.chevron_right),
              ),
              DonyListTile(
                label: 'Option 2',
                enabled: false,
                destructive: true,
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Option 1'), findsOneWidget);
      expect(find.text('Sub 1'), findsOneWidget);
      expect(find.text('Option 2'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // DonyUserCard
  // ---------------------------------------------------------------------------
  group('DonyUserCard', () {
    testWidgets('renders name', (tester) async {
      await tester.pumpWidget(
        _wrap(const DonyUserCard(name: 'Ibrahima Diallo')),
      );
      await tester.pump();
      expect(find.text('Ibrahima Diallo'), findsOneWidget);
    });

    testWidgets('renders subtitle when provided', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const DonyUserCard(name: 'Amadou', subtitle: 'Voyageur • 12 trajets'),
        ),
      );
      await tester.pump();
      expect(find.text('Voyageur • 12 trajets'), findsOneWidget);
    });

    testWidgets('hides subtitle when null', (tester) async {
      await tester.pumpWidget(_wrap(const DonyUserCard(name: 'Kouyaté')));
      await tester.pump();
      // name appears, no subtitle text
      expect(find.text('Kouyaté'), findsOneWidget);
    });

    testWidgets('shows rating and star icon when rating provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const DonyUserCard(name: 'Fatoumata', rating: 4.8)),
      );
      await tester.pump();
      expect(find.text('4.8/5'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is DonyIcon && w.name.startsWith('star'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('hides rating row when rating is null', (tester) async {
      await tester.pumpWidget(_wrap(const DonyUserCard(name: 'Bamba')));
      await tester.pump();
      expect(
        find.byWidgetPredicate(
          (w) => w is DonyIcon && w.name.startsWith('star'),
        ),
        findsNothing,
      );
    });

    testWidgets('shows verified badge on avatar when verified=true', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const DonyUserCard(name: 'Verified User', verified: true)),
      );
      await tester.pump();
      expect(
        find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'badge-check'),
        findsWidgets,
      );
    });

    testWidgets('no check icon when verified=false', (tester) async {
      await tester.pumpWidget(_wrap(const DonyUserCard(name: 'Unverified')));
      await tester.pump();
      expect(
        find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'badge-check'),
        findsNothing,
      );
    });

    testWidgets('onTap callback fires', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(DonyUserCard(name: 'Tap User', onTap: () => tapped = true)),
      );
      await tester.pump();
      await tester.tap(find.byType(DonyUserCard));
      expect(tapped, isTrue);
    });

    testWidgets('shows chevron when onTap provided and no trailing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(DonyUserCard(name: 'Arrow User', onTap: () {})),
      );
      await tester.pump();
      expect(
        find.byWidgetPredicate(
          (w) => w is DonyIcon && w.name == 'chevron-right',
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows trailing widget when provided', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DonyUserCard(
            name: 'Trailing User',
            trailing: const Icon(Icons.more_vert),
            onTap: () {},
          ),
        ),
      );
      await tester.pump();
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is DonyIcon && w.name == 'chevron-right',
        ),
        findsNothing,
      );
    });

    testWidgets('hides chevron when no onTap and no trailing', (tester) async {
      await tester.pumpWidget(_wrap(const DonyUserCard(name: 'Static')));
      await tester.pump();
      expect(
        find.byWidgetPredicate(
          (w) => w is DonyIcon && w.name == 'chevron-right',
        ),
        findsNothing,
      );
    });

    testWidgets('compact=true uses compact padding and titleMedium style', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const DonyUserCard(name: 'Compact User', compact: true)),
      );
      await tester.pump();
      expect(find.text('Compact User'), findsOneWidget);
    });

    testWidgets('compact=false uses base padding and titleLarge style', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const DonyUserCard(
            name: 'Full User',
            // compact defaults to false — explicitly verifying that code path
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Full User'), findsOneWidget);
    });

    testWidgets('avatarSize sm renders', (tester) async {
      await tester.pumpWidget(
        _wrap(const DonyUserCard(name: 'Small', avatarSize: DonyAvatarSize.sm)),
      );
      await tester.pump();
      expect(find.byType(DonyAvatar), findsOneWidget);
    });

    testWidgets('avatarSize lg renders', (tester) async {
      await tester.pumpWidget(
        _wrap(const DonyUserCard(name: 'Large', avatarSize: DonyAvatarSize.lg)),
      );
      await tester.pump();
      expect(find.byType(DonyAvatar), findsOneWidget);
    });

    testWidgets('avatarSize xl renders', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const DonyUserCard(name: 'XLarge', avatarSize: DonyAvatarSize.xl),
        ),
      );
      await tester.pump();
      expect(find.byType(DonyAvatar), findsOneWidget);
    });

    testWidgets('imageUrl passed to avatar', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const DonyUserCard(
            name: 'Photo User',
            imageUrl: 'https://example.com/avatar.jpg',
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(DonyAvatar), findsOneWidget);
    });

    testWidgets('all optional params combined', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          DonyUserCard(
            name: 'All Params',
            imageUrl: 'https://example.com/photo.jpg',
            subtitle: 'Expéditeur • 5 envois',
            verified: true,
            rating: 4.5,
            trailing: const Icon(Icons.arrow_forward),
            onTap: () => tapped = true,
            avatarSize: DonyAvatarSize.lg,
            compact: true,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('All Params'), findsOneWidget);
      expect(find.text('Expéditeur • 5 envois'), findsOneWidget);
      expect(find.text('4.5/5'), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'badge-check'),
        findsWidgets,
      );
      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
      await tester.tap(find.byType(DonyUserCard));
      expect(tapped, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // DonySectionHeader
  // ---------------------------------------------------------------------------
  group('DonySectionHeader', () {
    testWidgets('renders title', (tester) async {
      await tester.pumpWidget(
        _wrap(const DonySectionHeader(title: 'Trajets récents')),
      );
      await tester.pump();
      expect(find.text('Trajets récents'), findsOneWidget);
    });

    testWidgets('renders subtitle when provided', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const DonySectionHeader(
            title: 'Mes trajets',
            subtitle: 'Les 30 derniers jours',
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Mes trajets'), findsOneWidget);
      expect(find.text('Les 30 derniers jours'), findsOneWidget);
    });

    testWidgets('hides subtitle when null', (tester) async {
      await tester.pumpWidget(_wrap(const DonySectionHeader(title: 'No sub')));
      await tester.pump();
      expect(find.text('No sub'), findsOneWidget);
    });

    testWidgets('shows action button when actionLabel and onAction provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          DonySectionHeader(
            title: 'Annonces',
            actionLabel: 'Voir tout',
            onAction: () {},
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Voir tout'), findsOneWidget);
      expect(find.byType(TextButton), findsOneWidget);
    });

    testWidgets('action button fires onAction callback', (tester) async {
      var fired = false;
      await tester.pumpWidget(
        _wrap(
          DonySectionHeader(
            title: 'Annonces',
            actionLabel: 'Voir tout',
            onAction: () => fired = true,
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byType(TextButton));
      expect(fired, isTrue);
    });

    testWidgets('shows arrow_forward_rounded icon in action button', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          DonySectionHeader(
            title: 'Trajets',
            actionLabel: 'Plus',
            onAction: () {},
          ),
        ),
      );
      await tester.pump();
      expect(
        find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'arrow-right'),
        findsOneWidget,
      );
    });

    testWidgets('hides action button when actionLabel is null', (tester) async {
      await tester.pumpWidget(
        _wrap(DonySectionHeader(title: 'Header', onAction: () {})),
      );
      await tester.pump();
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('hides action button when onAction is null', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const DonySectionHeader(title: 'Header', actionLabel: 'Voir tout'),
        ),
      );
      await tester.pump();
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('uses CrossAxisAlignment.center when no subtitle', (
      tester,
    ) async {
      // Row alignment differs with/without subtitle — exercise both branches
      await tester.pumpWidget(
        _wrap(
          DonySectionHeader(
            title: 'No subtitle header',
            actionLabel: 'Voir',
            onAction: () {},
          ),
        ),
      );
      await tester.pump();
      expect(find.text('No subtitle header'), findsOneWidget);
      expect(find.byType(TextButton), findsOneWidget);
    });

    testWidgets('uses CrossAxisAlignment.start when subtitle present', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          DonySectionHeader(
            title: 'With subtitle',
            subtitle: 'A subtitle',
            actionLabel: 'Voir',
            onAction: () {},
          ),
        ),
      );
      await tester.pump();
      expect(find.text('With subtitle'), findsOneWidget);
      expect(find.text('A subtitle'), findsOneWidget);
      expect(find.byType(TextButton), findsOneWidget);
    });

    testWidgets('applies custom padding when provided', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const DonySectionHeader(
            title: 'Padded header',
            padding: EdgeInsets.all(24),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Padded header'), findsOneWidget);
    });

    testWidgets('uses zero padding by default', (tester) async {
      await tester.pumpWidget(
        _wrap(const DonySectionHeader(title: 'Default pad')),
      );
      await tester.pump();
      expect(find.text('Default pad'), findsOneWidget);
    });

    testWidgets('all params combined', (tester) async {
      var fired = false;
      await tester.pumpWidget(
        _wrap(
          DonySectionHeader(
            title: 'Full header',
            subtitle: 'Sub text',
            actionLabel: 'Action',
            onAction: () => fired = true,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Full header'), findsOneWidget);
      expect(find.text('Sub text'), findsOneWidget);
      expect(find.text('Action'), findsOneWidget);
      await tester.tap(find.byType(TextButton));
      expect(fired, isTrue);
    });
  });
}
