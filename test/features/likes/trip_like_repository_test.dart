import 'package:dony/features/likes/data/datasources/trip_like_remote_datasource.dart';
import 'package:dony/features/likes/data/models/trip_like_status.dart';
import 'package:dony/features/likes/data/repositories/trip_like_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDatasource extends Mock implements TripLikeRemoteDatasource {}

void main() {
  late _MockDatasource ds;
  late TripLikeRepository repo;
  const status = TripLikeStatus(likeCount: 2, likedByMe: true);

  setUp(() {
    ds = _MockDatasource();
    repo = TripLikeRepository(ds);
  });

  test('like délègue à la datasource', () async {
    when(() => ds.like('t1')).thenAnswer((_) async => status);
    expect(await repo.like('t1'), status);
    verify(() => ds.like('t1')).called(1);
  });

  test('unlike délègue à la datasource', () async {
    when(() => ds.unlike('t1')).thenAnswer((_) async => status);
    expect(await repo.unlike('t1'), status);
    verify(() => ds.unlike('t1')).called(1);
  });

  test('propage les erreurs', () {
    when(() => ds.like(any())).thenThrow(Exception('boom'));
    expect(() => repo.like('t1'), throwsException);
  });
}
