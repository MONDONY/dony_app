import 'package:dony/features/receptions/data/models/parcel_role.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lit les quatre rôles', () {
    expect(parcelRoleFromJson('SENDER'), ParcelRole.sender);
    expect(parcelRoleFromJson('TRAVELER'), ParcelRole.traveler);
    expect(parcelRoleFromJson('RECIPIENT'), ParcelRole.recipient);
    expect(parcelRoleFromJson('NONE'), ParcelRole.none);
  });

  test('valeur inconnue ou absente : none', () {
    expect(parcelRoleFromJson('ADMIN'), ParcelRole.none);
    expect(parcelRoleFromJson(null), ParcelRole.none);
  });
}
