enum Role {
  buyer('buyer'),
  seller('seller'),
  admin('admin');

  final String value;

  const Role(this.value);

  /// Converts a string value to its corresponding Roie enum value.
  ///
  /// Throws an ArgumentError if the string doesn't match any Role value.
  static final _valueMap = {
    for (var action in Role.values) action.value: action
  };

  static Role fromString(String value) {
    final action = _valueMap[value];
    if (action == null) {
      throw ArgumentError('Invalid Role: $value');
    }
    return action;
  }

  @override
  String toString() {
    return value;
  }
}
