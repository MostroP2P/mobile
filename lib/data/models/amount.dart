class Amount {
  final int minimum;
  final int? maximum;

  Amount(this.minimum, this.maximum);

  factory Amount.fromList(List<String> fa) {
    if (fa.length < 2) {
      throw ArgumentError(
          'List must have at least two elements: a label and a minimum value.');
    }

    final min = int.tryParse(fa[1]);
    if (min == null) {
      throw ArgumentError(
          'Second element must be a valid integer representing the minimum value.');
    }

    int? max;
    if (fa.length > 2) {
      max = int.tryParse(fa[2]);
    }

    return Amount(min, max);
  }

  factory Amount.empty() {
    return Amount(0, null);
  }

  @override
  String toString() {
    if (maximum != null) {
      return '$minimum - $maximum';
    } else {
      return '$minimum';
    }
  }
}
