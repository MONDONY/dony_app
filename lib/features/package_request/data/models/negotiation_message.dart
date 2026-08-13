import 'package:equatable/equatable.dart';

enum NegotiationMessageKind {
  proposal('PROPOSAL'),
  counter('COUNTER'),
  accept('ACCEPT'),
  reject('REJECT');

  final String wireName;
  const NegotiationMessageKind(this.wireName);

  static NegotiationMessageKind fromJson(String s) =>
      NegotiationMessageKind.values.firstWhere((e) => e.wireName == s);
}

class NegotiationMessage extends Equatable {
  const NegotiationMessage({
    required this.id,
    required this.threadId,
    required this.fromUserId,
    required this.kind,
    this.proposedPriceEur,
    this.body,
    required this.createdAt,
  });

  final String id;
  final String threadId;
  final String fromUserId;
  final NegotiationMessageKind kind;
  final double? proposedPriceEur;
  final String? body;
  final DateTime createdAt;

  factory NegotiationMessage.fromJson(Map<String, dynamic> json) =>
      NegotiationMessage(
        id: json['id'] as String,
        threadId: json['threadId'] as String,
        fromUserId: json['fromUserId'] as String,
        kind: NegotiationMessageKind.fromJson(json['kind'] as String),
        proposedPriceEur: (json['proposedPriceEur'] as num?)?.toDouble(),
        body: json['body'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  @override
  List<Object?> get props => [
    id,
    threadId,
    fromUserId,
    kind,
    proposedPriceEur,
    body,
    createdAt,
  ];
}
