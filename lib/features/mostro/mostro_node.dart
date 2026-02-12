/// Sentinel value to explicitly clear an optional field in [MostroNode.withMetadata].
const String _clearField = '__clear__';

class MostroNode {
  final String pubkey;
  String? name;
  String? picture;
  String? website;
  String? about;
  final bool isTrusted;
  final DateTime? addedAt;

  MostroNode({
    required this.pubkey,
    this.name,
    this.picture,
    this.website,
    this.about,
    this.isTrusted = false,
    this.addedAt,
  });

  /// Sentinel value to explicitly clear a metadata field.
  /// Usage: `node.withMetadata(name: MostroNode.clear)`
  static const String clear = _clearField;

  /// Validates a 64-character hex public key string.
  static final RegExp hexPubkeyRegex = RegExp(r'^[0-9a-fA-F]{64}$');

  /// Returns true if [value] is a valid 64-character hex public key.
  static bool isValidHexPubkey(String value) => hexPubkeyRegex.hasMatch(value);

  String get displayName => name ?? pubkey;

  /// Returns a copy with updated metadata fields.
  /// - Pass a value to set it.
  /// - Pass `null` (or omit) to keep the current value.
  /// - Pass [MostroNode.clear] to explicitly set the field to `null`.
  MostroNode withMetadata({
    String? name,
    String? picture,
    String? website,
    String? about,
  }) {
    return MostroNode(
      pubkey: pubkey,
      name: name == _clearField ? null : (name ?? this.name),
      picture: picture == _clearField ? null : (picture ?? this.picture),
      website: website == _clearField ? null : (website ?? this.website),
      about: about == _clearField ? null : (about ?? this.about),
      isTrusted: isTrusted,
      addedAt: addedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pubkey': pubkey,
      'name': name,
      'picture': picture,
      'website': website,
      'about': about,
      'isTrusted': isTrusted,
      'addedAt': addedAt?.millisecondsSinceEpoch,
    };
  }

  factory MostroNode.fromJson(Map<String, dynamic> json) {
    return MostroNode(
      pubkey: json['pubkey'] as String,
      name: json['name'] as String?,
      picture: json['picture'] as String?,
      website: json['website'] as String?,
      about: json['about'] as String?,
      isTrusted: json['isTrusted'] as bool? ?? false,
      addedAt: json['addedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['addedAt'] as int)
          : null,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MostroNode && other.pubkey == pubkey;
  }

  @override
  int get hashCode => pubkey.hashCode;

  @override
  String toString() {
    return 'MostroNode(pubkey: $pubkey, name: $name, trusted: $isTrusted)';
  }
}
