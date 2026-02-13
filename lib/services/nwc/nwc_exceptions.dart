/// Base exception for all NWC-related errors.
class NwcException implements Exception {
  final String message;
  const NwcException(this.message);

  @override
  String toString() => 'NwcException: $message';
}

/// Thrown when a NWC connection URI is invalid or malformed.
class NwcInvalidUriException extends NwcException {
  const NwcInvalidUriException(super.message);

  @override
  String toString() => 'NwcInvalidUriException: $message';
}

/// Thrown when the wallet service returns an error response.
class NwcResponseException extends NwcException {
  /// The NWC error code (e.g., PAYMENT_FAILED, UNAUTHORIZED).
  final NwcErrorCode code;

  const NwcResponseException(this.code, super.message);

  @override
  String toString() => 'NwcResponseException($code): $message';
}

/// Thrown when a request to the wallet service times out.
class NwcTimeoutException extends NwcException {
  const NwcTimeoutException([String message = 'Request timed out'])
      : super(message);

  @override
  String toString() => 'NwcTimeoutException: $message';
}

/// Thrown when the NWC client is not connected.
class NwcNotConnectedException extends NwcException {
  const NwcNotConnectedException([String message = 'Not connected to relay'])
      : super(message);

  @override
  String toString() => 'NwcNotConnectedException: $message';
}

/// NWC error codes as defined in NIP-47.
enum NwcErrorCode {
  rateLimited('RATE_LIMITED'),
  notImplemented('NOT_IMPLEMENTED'),
  insufficientBalance('INSUFFICIENT_BALANCE'),
  quotaExceeded('QUOTA_EXCEEDED'),
  restricted('RESTRICTED'),
  unauthorized('UNAUTHORIZED'),
  internal('INTERNAL'),
  paymentFailed('PAYMENT_FAILED'),
  notFound('NOT_FOUND'),
  unsupportedEncryption('UNSUPPORTED_ENCRYPTION'),
  other('OTHER');

  final String value;
  const NwcErrorCode(this.value);

  /// Parses a string error code into an [NwcErrorCode].
  /// Returns [NwcErrorCode.other] for unrecognized codes.
  static NwcErrorCode fromString(String code) {
    return NwcErrorCode.values.firstWhere(
      (e) => e.value == code,
      orElse: () => NwcErrorCode.other,
    );
  }
}
