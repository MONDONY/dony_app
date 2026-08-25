import 'dart:convert';
import 'dart:io';

import 'package:dony/core/network/tls_pinned_ca.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('tlsPinnedIssuerPem', () {
    // Régression : le pinning comparait auparavant une empreinte dans
    // `badCertificateCallback`. Ce rappel reçoit le certificat au niveau
    // duquel la validation échoue, soit le sommet de la chaîne présentée,
    // jamais celui du serveur. L'empreinte de la feuille n'y correspondait
    // donc jamais et la production refusait tous les appels. L'ancre de
    // confiance est désormais ce certificat : s'il est vide ou tronqué,
    // plus rien ne se connecte.
    test('contient un certificat complet', () {
      expect(tlsPinnedIssuerPem, contains('-----BEGIN CERTIFICATE-----'));
      expect(tlsPinnedIssuerPem, contains('-----END CERTIFICATE-----'));
    });

    test('est accepté par SecurityContext comme ancre de confiance', () {
      final octets = const Utf8Encoder().convert(tlsPinnedIssuerPem);
      expect(
        () => SecurityContext()..setTrustedCertificatesBytes(octets),
        returnsNormally,
        reason:
            'un PEM tronqué ou mal formé lèverait ici, et aucun appel réseau '
            'ne passerait plus une fois le binaire distribué',
      );
    });

    // Épingler la feuille condamnerait l'app à chaque renouvellement
    // Let's Encrypt, tous les 90 jours environ.
    test('épingle un émetteur, pas le certificat du serveur', () {
      expect(tlsPinnedIssuerPem, isNot(contains('api.yadony.com')));
    });
  });
}
