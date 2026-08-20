import 'package:dony/features/home/data/datasources/search_parse_datasource.dart';
import 'package:dony/features/home/data/models/search_parse_result.dart';
import 'package:dony/features/home/domain/search_mode.dart';

class SearchParseRepository {
  const SearchParseRepository(this._datasource);

  final SearchParseDatasource _datasource;

  Future<SearchParseResult> parse(String text, SearchMode mode) =>
      _datasource.parse(text, mode);
}
