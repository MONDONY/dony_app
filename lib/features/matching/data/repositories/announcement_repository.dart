import 'package:dony/features/matching/data/datasources/announcement_remote_datasource.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';

class AnnouncementRepository {
  final AnnouncementRemoteDatasource _remoteDatasource;

  AnnouncementRepository(this._remoteDatasource);

  Future<AnnouncementModel> createAnnouncement({
    required String departureCity,
    required String arrivalCity,
    required DateTime departureDate,
    String? departureTime,
    String? arrivalTime,
    String? departureLocation,
    String? arrivalLocation,
    required double availableKg,
    required double pricePerKg,
  }) async {
    return _remoteDatasource.createAnnouncement(
      departureCity: departureCity,
      arrivalCity: arrivalCity,
      departureDate: departureDate,
      departureTime: departureTime,
      arrivalTime: arrivalTime,
      departureLocation: departureLocation,
      arrivalLocation: arrivalLocation,
      availableKg: availableKg,
      pricePerKg: pricePerKg,
    );
  }

  Future<List<AnnouncementModel>> getMyAnnouncements({int page = 0}) async {
    return _remoteDatasource.getMyAnnouncements(page: page);
  }

  Future<AnnouncementModel> getAnnouncementDetail(String id) async {
    return _remoteDatasource.getAnnouncementDetail(id);
  }

  Future<List<AnnouncementModel>> searchAnnouncements({
    String? departureCity,
    String? arrivalCity,
    DateTime? departureDateFrom,
    DateTime? departureDateTo,
    double? minAvailableKg,
    String sortBy = 'date',
    String sortDir = 'asc',
  }) {
    return _remoteDatasource.searchAnnouncements(
      departureCity: departureCity,
      arrivalCity: arrivalCity,
      departureDateFrom: departureDateFrom,
      departureDateTo: departureDateTo,
      minAvailableKg: minAvailableKg,
      sortBy: sortBy,
      sortDir: sortDir,
    );
  }

  Future<void> deleteAnnouncement(String id) async {
    return _remoteDatasource.deleteAnnouncement(id);
  }

  Future<AnnouncementModel> updateAnnouncement({
    required String id,
    required String departureCity,
    required String arrivalCity,
    required DateTime departureDate,
    String? departureTime,
    String? arrivalTime,
    String? departureLocation,
    String? arrivalLocation,
    required double availableKg,
    required double pricePerKg,
  }) async {
    return _remoteDatasource.updateAnnouncement(
      id: id,
      departureCity: departureCity,
      arrivalCity: arrivalCity,
      departureDate: departureDate,
      departureTime: departureTime,
      arrivalTime: arrivalTime,
      departureLocation: departureLocation,
      arrivalLocation: arrivalLocation,
      availableKg: availableKg,
      pricePerKg: pricePerKg,
    );
  }
}
