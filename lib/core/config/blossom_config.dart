/// Configuration for Blossom server settings and upload parameters
class BlossomConfig {
  /// Default Blossom servers used for media uploads
  ///
  /// These servers are tried in order when uploading files.
  /// If one fails, the next server in the list is attempted.
  ///
  /// Chat attachments are encrypted before upload, so they are sent as
  /// `application/octet-stream`. Only add servers that accept opaque blobs:
  /// media-only servers reject them by sniffing the content, which fails
  /// every attachment regardless of the original file type.
  ///
  /// Servers must also retain blobs indefinitely. Ephemeral hosts expire
  /// files after weeks, which would silently break dispute evidence.
  static const List<String> defaultServers = [
    'https://cdn.hzrd149.com',
    'https://nostr.download',
    'https://blossom-01.uid.ovh',
    'https://files.sovbit.host',
    'https://blssm.us',
  ];
  
  /// Default upload timeout duration
  static const Duration defaultTimeout = Duration(minutes: 5);
  
  /// Maximum retry attempts per server
  static const int maxRetries = 3;
  
  /// Private constructor to prevent instantiation
  BlossomConfig._();
}