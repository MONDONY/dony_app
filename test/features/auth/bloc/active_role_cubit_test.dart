import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/auth/bloc/active_role_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';

class MockHiveService extends Mock implements HiveService {}
class MockBox extends Mock implements Box {}

void main() {
  late MockHiveService mockHive;
  late MockBox mockBox;

  setUp(() {
    mockHive = MockHiveService();
    mockBox = MockBox();
    when(() => mockHive.userPrefs).thenReturn(mockBox);
  });

  group('ActiveRoleCubit — état initial', () {
    test('démarre en mode Expéditeur quand aucune valeur sauvegardée', () {
      when(() => mockBox.get('active_role')).thenReturn(null);
      final cubit = ActiveRoleCubit(hiveService: mockHive);
      expect(cubit.state, ActiveRole.sender);
      cubit.close();
    });

    test('démarre en mode Voyageur quand TRAVELER est sauvegardé', () {
      when(() => mockBox.get('active_role')).thenReturn('TRAVELER');
      final cubit = ActiveRoleCubit(hiveService: mockHive);
      expect(cubit.state, ActiveRole.traveler);
      cubit.close();
    });

    test('démarre en mode Expéditeur quand SENDER est sauvegardé', () {
      when(() => mockBox.get('active_role')).thenReturn('SENDER');
      final cubit = ActiveRoleCubit(hiveService: mockHive);
      expect(cubit.state, ActiveRole.sender);
      cubit.close();
    });
  });

  group('ActiveRoleCubit — switchToTraveler', () {
    test('émet traveler et persiste TRAVELER dans Hive', () {
      when(() => mockBox.get('active_role')).thenReturn(null);
      when(() => mockBox.put(any(), any())).thenAnswer((_) async {});
      final cubit = ActiveRoleCubit(hiveService: mockHive);
      cubit.switchToTraveler();
      expect(cubit.state, ActiveRole.traveler);
      verify(() => mockBox.put('active_role', 'TRAVELER')).called(1);
      cubit.close();
    });
  });

  group('ActiveRoleCubit — switchToSender', () {
    test('émet sender et persiste SENDER dans Hive', () {
      when(() => mockBox.get('active_role')).thenReturn('TRAVELER');
      when(() => mockBox.put(any(), any())).thenAnswer((_) async {});
      final cubit = ActiveRoleCubit(hiveService: mockHive);
      cubit.switchToSender();
      expect(cubit.state, ActiveRole.sender);
      verify(() => mockBox.put('active_role', 'SENDER')).called(1);
      cubit.close();
    });
  });

  group('ActiveRoleCubit — reset', () {
    test('revient à sender (nouveau défaut) après reset', () {
      when(() => mockBox.get('active_role')).thenReturn('TRAVELER');
      when(() => mockBox.delete(any())).thenAnswer((_) async {});
      final cubit = ActiveRoleCubit(hiveService: mockHive);
      cubit.reset();
      expect(cubit.state, ActiveRole.sender);
      cubit.close();
    });
  });
}
