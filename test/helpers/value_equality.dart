import 'package:flutter_test/flutter_test.dart';

/// Vérifie l'égalité de valeur d'un objet `Equatable` (event ou state BLoC).
///
/// [build] est appelé deux fois : les deux instances, construites à
/// l'exécution (jamais `const`, sans quoi elles seraient identiques et
/// `Equatable` ne comparerait pas leurs `props`), doivent être égales et
/// partager leur `hashCode`. Chaque objet de [different] diffère d'un champ ou
/// du type, et ne doit pas être égal.
///
/// Les fichiers qui l'utilisent désactivent `prefer_const_constructors` : un
/// constructeur `const` n'est exécuté qu'à l'exécution d'un appel non `const`.
void expectValueEquality<T>(T Function() build, List<Object> different) {
  final a = build();
  final b = build();
  expect(identical(a, b), isFalse, reason: 'instances construites à neuf');
  expect(a, equals(b));
  expect(a.hashCode, b.hashCode);
  for (final other in different) {
    expect(a, isNot(equals(other)));
  }
}
