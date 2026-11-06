import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dony/core/network/tls_pinned_ca.dart';
import 'package:flutter_test/flutter_test.dart';

/// Empreintes SHA-256 (DER) publiées par Let's Encrypt,
/// https://letsencrypt.org/certificates/, relues avec
/// `openssl x509 -noout -fingerprint -sha256`.
const _rootYe =
    'e14ffcad5b0025731006caa43a121a22d8e9700f4fb9cf852f02a708aa5d5666';
const _rootYr =
    'e57b7e6f150c419102e8d5c055729ff967b9d1a829bf00cec89ca604ebf4a86f';
const _isrgRootX1 =
    '96bcec06264976f37460779acf28c5a7cfe8a3c0aae11a8ffcee05c0bddf08c6';
const _isrgRootX2 =
    '69729b8e15a86efc177a57afb7171dfc64add28c2fca8cf1507e34453ccb1470';

/// Intermédiaire `YE1`, seule ancre jusqu'au 06/11/2026.
const _intermediateYe1 =
    'a2372d06431e9716365eeed47ec020351497d182fcc038e457e58168a03cac07';

List<String> _fingerprints(String bundle) {
  final blocks = RegExp(
    '-----BEGIN CERTIFICATE-----([^-]+)-----END CERTIFICATE-----',
  ).allMatches(bundle);
  return [
    for (final block in blocks)
      sha256
          .convert(base64.decode(block.group(1)!.replaceAll(RegExp(r'\s'), '')))
          .toString(),
  ];
}

void main() {
  group('tlsPinnedRootsPem', () {
    // Régression : le pinning comparait auparavant une empreinte dans
    // `badCertificateCallback`. Ce rappel reçoit le certificat au niveau
    // duquel la validation échoue, soit le sommet de la chaîne présentée,
    // jamais celui du serveur. L'empreinte de la feuille n'y correspondait
    // donc jamais et la production refusait tous les appels. Les ancres de
    // confiance sont désormais ces certificats : s'ils sont vides ou
    // tronqués, plus rien ne se connecte.
    test('contient des certificats complets', () {
      expect(tlsPinnedRootsPem, contains('-----BEGIN CERTIFICATE-----'));
      expect(tlsPinnedRootsPem, contains('-----END CERTIFICATE-----'));
    });

    test('est accepté par SecurityContext comme ancre de confiance', () {
      final octets = const Utf8Encoder().convert(tlsPinnedRootsPem);
      expect(
        () => SecurityContext()..setTrustedCertificatesBytes(octets),
        returnsNormally,
        reason:
            'un PEM tronqué ou mal formé lèverait ici, et aucun appel réseau '
            'ne passerait plus une fois le binaire distribué',
      );
    });

    // Let's Encrypt émet depuis plusieurs intermédiaires à la fois (YE1 et
    // YE2 en ECDSA, YR1 et YR2 en RSA, YE3 et YR3 en secours « at any time,
    // without warning ») et en tire un à chaque renouvellement. N'épingler
    // que YE1 coupait l'API à toutes les apps installées dès qu'un
    // certificat sortait de YE2 : mesuré le 06/11/2026, letsencrypt.org
    // (YE2) et debian.org (YR1) étaient refusés par l'ancien réglage.
    test('épingle exactement les quatre racines ISRG', () {
      expect(_fingerprints(tlsPinnedRootsPem).toSet(), {
        _rootYe,
        _rootYr,
        _isrgRootX1,
        _isrgRootX2,
      });
    });

    test("n'épingle aucun intermédiaire, qui tourne sans préavis", () {
      expect(
        _fingerprints(tlsPinnedRootsPem),
        isNot(contains(_intermediateYe1)),
      );
    });

    // Épingler la feuille condamnerait l'app à chaque renouvellement
    // Let's Encrypt, tous les 90 jours environ.
    test('épingle des autorités, pas le certificat du serveur', () {
      expect(tlsPinnedRootsPem, isNot(contains('api.yadony.com')));
    });
  });
}
