import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/publish_gate/data/models/publish_commitments.dart';

AnnouncementModel tripFixture({
  String id = 'a1',
  String status = 'DRAFT',
  String departureCity = 'Paris',
  String arrivalCity = 'Dakar',
  DateTime? updatedAt,
}) => AnnouncementModel.fromJson({
  'id': id,
  'travelerId': 't1',
  'departureCity': departureCity,
  'arrivalCity': arrivalCity,
  'departureDate': DateTime(2026, 11, 20).toIso8601String(),
  'totalKg': 23,
  'availableKg': 23,
  'pricePerKg': 8.0,
  'pricingMode': 'KG',
  'currency': 'EUR',
  'status': status,
  'createdAt': '2026-10-01T00:00:00Z',
  'updatedAt': (updatedAt ?? DateTime.utc(2026, 10)).toIso8601String(),
});

PackageRequest requestFixture({
  String id = 'pr-1',
  PackageRequestStatus status = PackageRequestStatus.draft,
  DateTime? createdAt,
}) => PackageRequest(
  id: id,
  senderId: 's-1',
  departureCity: 'Lyon',
  arrivalCity: 'Abidjan',
  desiredDate: DateTime(2026, 11, 15),
  dateToleranceDays: 2,
  weightKg: 5,
  parcelSize: ParcelSize.medium,
  transportMode: TransportMode.plane,
  categories: const ['Vêtements'],
  status: status,
  createdAt: createdAt ?? DateTime(2026, 10),
);

PublishCommitments commitments({
  bool travelerRequired = true,
  bool senderRequired = true,
  String version = '2026-10',
}) => PublishCommitments(
  currentVersion: version,
  traveler: PublishCommitmentStatus(
    required: travelerRequired,
    acceptedVersion: travelerRequired ? null : version,
  ),
  sender: PublishCommitmentStatus(
    required: senderRequired,
    acceptedVersion: senderRequired ? null : version,
  ),
);
