class RangeAmount {
  final int minimum;
  final int? maximum;

  RangeAmount(this.minimum, this.maximum);

  factory RangeAmount.fromList(List<String> fa) {
    if (fa.length < 2) {
      throw ArgumentError(
          'List must have at least two elements: a label and a minimum value.');
    }

    final min = int.tryParse(fa[1]) ?? 0;

    int? max;
    if (fa.length > 2) {
      max = int.tryParse(fa[2]);
    }

    return RangeAmount(min, max);
  }

  factory RangeAmount.empty() {
    return RangeAmount(0, null);
  }

  bool isRange() {
    return maximum != null ? true : false;
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
