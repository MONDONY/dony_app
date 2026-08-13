class QrCodeModel {
  final String bidId;
  final String scanUrl;
  final String qrCodeBase64;

  const QrCodeModel({
    required this.bidId,
    required this.scanUrl,
    required this.qrCodeBase64,
  });

  factory QrCodeModel.fromJson(Map<String, dynamic> json) => QrCodeModel(
    bidId: json['bidId'] as String,
    scanUrl: json['scanUrl'] as String,
    qrCodeBase64: json['qrCodeBase64'] as String,
  );
}
