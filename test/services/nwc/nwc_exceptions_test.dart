import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/services/nwc/nwc_exceptions.dart';

void main() {
  group('NwcErrorCode', () {
    test('fromString maps all known codes', () {
      expect(NwcErrorCode.fromString('RATE_LIMITED'), NwcErrorCode.rateLimited);
      expect(NwcErrorCode.fromString('NOT_IMPLEMENTED'),
          NwcErrorCode.notImplemented);
      expect(NwcErrorCode.fromString('INSUFFICIENT_BALANCE'),
          NwcErrorCode.insufficientBalance);
      expect(
          NwcErrorCode.fromString('QUOTA_EXCEEDED'), NwcErrorCode.quotaExceeded);
      expect(NwcErrorCode.fromString('RESTRICTED'), NwcErrorCode.restricted);
      expect(NwcErrorCode.fromString('UNAUTHORIZED'), NwcErrorCode.unauthorized);
      expect(NwcErrorCode.fromString('INTERNAL'), NwcErrorCode.internal);
      expect(
          NwcErrorCode.fromString('PAYMENT_FAILED'), NwcErrorCode.paymentFailed);
      expect(NwcErrorCode.fromString('NOT_FOUND'), NwcErrorCode.notFound);
      expect(NwcErrorCode.fromString('UNSUPPORTED_ENCRYPTION'),
          NwcErrorCode.unsupportedEncryption);
      expect(NwcErrorCode.fromString('OTHER'), NwcErrorCode.other);
    });

    test('fromString returns other for unknown codes', () {
      expect(NwcErrorCode.fromString('UNKNOWN'), NwcErrorCode.other);
      expect(NwcErrorCode.fromString(''), NwcErrorCode.other);
    });
  });

  group('NWC Exceptions', () {
    test('NwcException toString', () {
      const ex = NwcException('test error');
      expect(ex.toString(), contains('test error'));
    });

    test('NwcInvalidUriException toString', () {
      const ex = NwcInvalidUriException('bad uri');
      expect(ex.toString(), contains('bad uri'));
      expect(ex, isA<NwcException>());
    });

    test('NwcResponseException includes code', () {
      const ex = NwcResponseException(NwcErrorCode.paymentFailed, 'failed');
      expect(ex.code, NwcErrorCode.paymentFailed);
      expect(ex.toString(), contains('paymentFailed'));
    });

    test('NwcTimeoutException default message', () {
      const ex = NwcTimeoutException();
      expect(ex.message, contains('timed out'));
    });

    test('NwcNotConnectedException default message', () {
      const ex = NwcNotConnectedException();
      expect(ex.message, contains('Not connected'));
    });
  });
}
