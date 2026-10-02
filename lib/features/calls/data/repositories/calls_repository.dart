import 'package:dony/features/calls/data/datasources/calls_datasource.dart';
import 'package:dony/features/calls/data/models/call_token.dart';
import 'package:dony/features/calls/data/models/started_call.dart';

class CallsRepository {
  CallsRepository(this._datasource);

  final CallsDatasource _datasource;

  Future<CallToken> fetchToken() => _datasource.fetchToken();

  Future<StartedCall> startCall(String conversationId) =>
      _datasource.startCall(conversationId);
}
