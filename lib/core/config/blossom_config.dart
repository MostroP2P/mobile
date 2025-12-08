/// Configuration for Blossom server settings and upload parameters
class BlossomConfig {
  /// Default Blossom servers used for media uploads
  /// 
  /// These servers are tried in order when uploading files.
  /// If one fails, the next server in the list is attempted.
  static const List<String> defaultServers = [
    'https://blossom.primal.net',
    'https://blossom.band',
    'https://nostr.media',
    'https://blossom.sector01.com',
    'https://24242.io',
    'https://otherstuff.shaving.kiwi',
    'https://blossom.f7z.io',
    'https://nosto.re',
    'https://blossom.poster.place',
  ];
  
  /// Default upload timeout duration
  static const Duration defaultTimeout = Duration(minutes: 5);
  
  /// Maximum retry attempts per server
  static const int maxRetries = 3;
  
  /// Private constructor to prevent instantiation
  BlossomConfig._();
}