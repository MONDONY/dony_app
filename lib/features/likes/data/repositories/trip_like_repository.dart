import 'package:dony/features/likes/data/datasources/trip_like_remote_datasource.dart';
import 'package:dony/features/likes/data/models/trip_like_status.dart';

class TripLikeRepository {
  TripLikeRepository(this._datasource);

  final TripLikeRemoteDatasource _datasource;

  Future<TripLikeStatus> like(String tripId) => _datasource.like(tripId);

  Future<TripLikeStatus> unlike(String tripId) => _datasource.unlike(tripId);
}
