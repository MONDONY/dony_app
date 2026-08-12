import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/disputes/data/datasources/dispute_remote_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements ApiClient {}
class _MockDio extends Mock implements Dio {}

void main() {
  test('getMyDisputes GET /disputes/me et parse la liste', () async {
    final api = _MockApiClient();
    final dio = _MockDio();
    when(() => api.dio).thenReturn(dio);
    when(() => dio.get<dynamic>('/disputes/me')).thenAnswer((_) async => Response(
          requestOptions: RequestOptions(path: '/disputes/me'),
          data: [
            {
              'id': 'd1',
              'bidId': null,
              'type': 'SENDER_NO_SHOW_CONTESTED',
              'status': 'OPEN',
              'refundFrozen': true,
              'createdAt': '2026-07-12T08:00:00',
              'myRole': 'SENDER',
              'otherPartyName': null,
              'departureCity': null,
              'arrivalCity': null,
              'departureCountryCode': null,
              'arrivalCountryCode': null,
              'tripDate': null,
              'weightKg': null,
              'resolutionType': null,
              'resolvedAt': null,
              'resolutionNote': null,
              'guaranteeAmountCents': null,
              'isBeneficiary': false,
            }
          ],
        ));

    final result = await DisputeRemoteDatasource(api).getMyDisputes();
    expect(result, hasLength(1));
    expect(result.first.id, 'd1');
  });
}
