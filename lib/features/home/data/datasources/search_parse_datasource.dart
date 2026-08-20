import 'package:dio/dio.dart';
import 'package:dony/features/home/data/models/search_parse_result.dart';
import 'package:dony/features/home/domain/search_mode.dart';

class SearchParseDatasource {
  const SearchParseDatasource({required Dio dio}) : _dio = dio;

  final Dio _dio;

  Future<SearchParseResult> parse(String text, SearchMode mode) async {
    final response = await _dio.post<dynamic>(
      '/search/parse',
      data: {'text': text, 'mode': wireModeOf(mode)},
    );
    return SearchParseResult.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }
}
