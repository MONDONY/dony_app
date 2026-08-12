import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/content_categories/data/content_category_datasource.dart';
import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/content_categories/data/content_category_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

const _apiPayload = [
  {'code': 'DOCUMENTS', 'label': 'Documents & administratif', 'emoji': '📄'},
  {'code': 'ALIMENTATION_SECHE', 'label': 'Alimentation sèche', 'emoji': '🍚'},
  {
    'code': 'PRODUITS_FRAIS',
    'label': 'Produits frais / périssables',
    'emoji': '🐟',
  },
  {'code': 'COSMETIQUES', 'label': 'Cosmétiques & parfums', 'emoji': '💄'},
  {'code': 'VETEMENTS', 'label': 'Vêtements & tissus', 'emoji': '👗'},
  {'code': 'CHAUSSURES', 'label': 'Chaussures', 'emoji': '👟'},
  {
    'code': 'MEDICAMENTS_TRADITIONNELS',
    'label': 'Médicaments traditionnels',
    'emoji': '🌿',
  },
  {'code': 'ELECTRONIQUE', 'label': 'Téléphone & électronique', 'emoji': '📱'},
  {'code': 'LIVRES', 'label': 'Livres', 'emoji': '📚'},
  {'code': 'CADEAUX', 'label': 'Cadeaux & jouets', 'emoji': '🎁'},
  {'code': 'AUTRE', 'label': 'Autre', 'emoji': '📦'},
];

void main() {
  late MockApiClient mockApiClient;
  late MockDio mockDio;
  late ContentCategoryDatasource datasource;
  late ContentCategoryRepository repository;

  setUp(() {
    mockApiClient = MockApiClient();
    mockDio = MockDio();
    when(() => mockApiClient.dio).thenReturn(mockDio);
    datasource = ContentCategoryDatasource(mockApiClient);
    repository = ContentCategoryRepository(datasource);
  });

  group('ContentCategoryRepository', () {
    test(
      'getCategories returns the 11 categories from the API, correctly deserialized',
      () async {
        when(() => mockDio.get('/config/content-categories')).thenAnswer(
          (_) async => Response(
            data: _apiPayload,
            statusCode: 200,
            requestOptions: RequestOptions(path: '/config/content-categories'),
          ),
        );

        final categories = await repository.getCategories();

        expect(categories, hasLength(11));
        expect(categories.first.code, 'DOCUMENTS');
        expect(categories.first.label, 'Documents & administratif');
        expect(categories.first.emoji, '📄');
      },
    );

    test('getCategories caches the result — no second HTTP call', () async {
      when(() => mockDio.get('/config/content-categories')).thenAnswer(
        (_) async => Response(
          data: _apiPayload,
          statusCode: 200,
          requestOptions: RequestOptions(path: '/config/content-categories'),
        ),
      );

      await repository.getCategories();
      await repository.getCategories();

      verify(() => mockDio.get('/config/content-categories')).called(1);
    });

    test(
      'getCategories returns fallbackCatalog on network failure — never throws',
      () async {
        when(() => mockDio.get('/config/content-categories')).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/config/content-categories'),
            message: 'Network error',
          ),
        );

        final categories = await repository.getCategories();

        expect(categories, fallbackCatalog);
        expect(categories, hasLength(11));
      },
    );
  });

  group('iconForCode', () {
    test('returns an icon for a known code', () {
      expect(iconForCode('DOCUMENTS'), isA<IconData>());
    });

    test('returns the generic fallback icon for an unknown code', () {
      expect(iconForCode('CODE_INCONNU'), Icons.inventory_2_rounded);
    });
  });

  group('emojiForLabel', () {
    test('returns the canonical emoji for a known label', () {
      expect(emojiForLabel('Documents & administratif'), '📄');
    });

    test('returns 📦 for a free-text label outside the catalog', () {
      expect(emojiForLabel('Poissons'), '📦');
    });

    test('returns 📦 for null', () {
      expect(emojiForLabel(null), '📦');
    });
  });

  group('splitContentCategoryLabels', () {
    test('splits, trims and drops empty entries', () {
      expect(
        splitContentCategoryLabels('Vêtements & tissus,Livres , Poissons'),
        ['Vêtements & tissus', 'Livres', 'Poissons'],
      );
    });

    test('returns an empty list for null or empty input', () {
      expect(splitContentCategoryLabels(null), isEmpty);
      expect(splitContentCategoryLabels(''), isEmpty);
    });
  });
}
