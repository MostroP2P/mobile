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

  String get displayName => name ?? truncatedPubkey;

  String get truncatedPubkey => pubkey.length > 10
      ? '${pubkey.substring(0, 5)}...${pubkey.substring(pubkey.length - 5)}'
      : pubkey;

  MostroNode withMetadata({
    String? name,
    String? picture,
    String? website,
    String? about,
  }) {
    return MostroNode(
      pubkey: pubkey,
      name: name ?? this.name,
      picture: picture ?? this.picture,
      website: website ?? this.website,
      about: about ?? this.about,
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
    return 'MostroNode(pubkey: $truncatedPubkey, name: $name, trusted: $isTrusted)';
  }
}
