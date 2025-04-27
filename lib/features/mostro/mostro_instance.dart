import 'package:dart_nostr/nostr/model/event/event.dart';

class MostroInstance {
  final String pubKey;
  final String mostroVersion;
  final String commitHash;
  final int maxOrderAmount;
  final int minOrderAmount;
  final int expirationHours;
  final int expirationSeconds;
  final double fee;
  final int pow;
  final int holdInvoiceExpirationWindow;
  final int holdInvoiceCltvDelta;
  final int invoiceExpirationWindow;

  MostroInstance(
    this.pubKey,
    this.mostroVersion,
    this.commitHash,
    this.maxOrderAmount,
    this.minOrderAmount,
    this.expirationHours,
    this.expirationSeconds,
    this.fee,
    this.pow,
    this.holdInvoiceExpirationWindow,
    this.holdInvoiceCltvDelta,
    this.invoiceExpirationWindow,
  );

  factory MostroInstance.fromEvent(NostrEvent event) {
    return MostroInstance(
      event.pubKey,
      event.mostroVersion,
      event.commitHash,
      event.maxOrderAmount,
      event.minOrderAmount,
      event.expirationHours,
      event.expirationSeconds,
      event.fee,
      event.pow,
      event.holdInvoiceExpirationWindow,
      event.holdInvoiceCltvDelta,
      event.invoiceExpirationWindow,
    );
  }
}

extension MostroInstanceExtensions on NostrEvent {
  String _getTagValue(String key) {
    final tag = tags?.firstWhere((t) => t[0] == key, orElse: () => []);
    return (tag != null && tag.length > 1) ? tag[1] : 'Tag: $key not found';
  }

  String get pubKey => _getTagValue('d');
  String get mostroVersion => _getTagValue('mostro_version');
  String get commitHash => _getTagValue('mostro_commit_hash');
  int get maxOrderAmount => int.parse(_getTagValue('max_order_amount'));
  int get minOrderAmount => int.parse(_getTagValue('min_order_amount'));
  int get expirationHours => int.parse(_getTagValue('expiration_hours'));
  int get expirationSeconds => int.parse(_getTagValue('expiration_seconds'));
  double get fee => double.parse(_getTagValue('fee'));
  int get pow => int.parse(_getTagValue('pow'));
  int get holdInvoiceExpirationWindow =>
      int.parse(_getTagValue('hold_invoice_expiration_window'));
  int get holdInvoiceCltvDelta =>
      int.parse(_getTagValue('hold_invoice_cltv_delta'));
  int get invoiceExpirationWindow =>
      int.parse(_getTagValue('invoice_expiration_window'));
}
