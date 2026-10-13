import 'package:dony/app/main_shell.dart';
import 'package:dony/features/flights/presentation/widgets/flight_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<double> reserveWith(WidgetTester tester, EdgeInsets padding) async {
    late double reserve;
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(padding: padding),
        child: Builder(
          builder: (context) {
            reserve = flightNavBarReserve(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return reserve;
  }

  testWidgets('réserve la hauteur de la barre d\'onglets sans encoche', (
    tester,
  ) async {
    expect(
      await reserveWith(tester, EdgeInsets.zero),
      MainShell.navBarContentHeight,
    );
  });

  testWidgets('ajoute la marge système du bas (barre de gestes)', (
    tester,
  ) async {
    expect(
      await reserveWith(tester, const EdgeInsets.only(bottom: 34)),
      MainShell.navBarContentHeight + 34,
    );
  });
}
