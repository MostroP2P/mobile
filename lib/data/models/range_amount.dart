class RangeAmount {
  final int minimum;
  final int? maximum;

  RangeAmount(this.minimum, this.maximum) {
    if (minimum < 0) {
      throw ArgumentError('Minimum amount cannot be negative: $minimum');
    }
    if (maximum != null && maximum! < 0) {
      throw ArgumentError('Maximum amount cannot be negative: $maximum');
    }
    if (maximum != null && maximum! < minimum) {
      throw ArgumentError('Maximum amount ($maximum) cannot be less than minimum ($minimum)');
    }
  }

  factory RangeAmount.fromList(List<String> fa) {
    try {
      if (fa.length < 2) {
        throw FormatException(
            'List must have at least two elements: a label and a minimum value.');
      }

      final minString = fa[1];
      if (minString.isEmpty) {
        throw FormatException('Minimum value string cannot be empty');
      }
      
      final min = double.tryParse(minString)?.toInt();
      if (min == null) {
        throw FormatException('Invalid minimum value format: $minString');
      }

      int? max;
      if (fa.length > 2) {
        final maxString = fa[2];
        if (maxString.isNotEmpty) {
          max = double.tryParse(maxString)?.toInt();
          if (max == null) {
            throw FormatException('Invalid maximum value format: $maxString');
          }
        }
      }

      return RangeAmount(min, max);
    } catch (e) {
      throw FormatException('Failed to parse RangeAmount from list: $e');
    }
  }

  factory RangeAmount.fromJson(Map<String, dynamic> json) {
    try {
      if (!json.containsKey('minimum')) {
        throw FormatException('Missing required field: minimum');
      }
      
      final minValue = json['minimum'];
      int minimum;
      if (minValue is int) {
        minimum = minValue;
      } else if (minValue is String) {
        minimum = int.tryParse(minValue) ??
            (throw FormatException('Invalid minimum format: $minValue'));
      } else {
        throw FormatException('Invalid minimum type: ${minValue.runtimeType}');
      }
      
      int? maximum;
      final maxValue = json['maximum'];
      if (maxValue != null) {
        if (maxValue is int) {
          maximum = maxValue;
        } else if (maxValue is String) {
          maximum = int.tryParse(maxValue) ??
              (throw FormatException('Invalid maximum format: $maxValue'));
        } else {
          throw FormatException('Invalid maximum type: ${maxValue.runtimeType}');
        }
      }
      
      return RangeAmount(minimum, maximum);
    } catch (e) {
      throw FormatException('Failed to parse RangeAmount from JSON: $e');
    }
  }

  factory RangeAmount.empty() {
    return RangeAmount(0, null);
  }

  Map<String, dynamic> toJson() {
    return {
      'minimum': minimum,
      if (maximum != null) 'maximum': maximum,
    };
  }

  bool isRange() {
    return maximum != null;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RangeAmount &&
        other.minimum == minimum &&
        other.maximum == maximum;
  }

  @override
  int get hashCode => Object.hash(minimum, maximum);

  @override
  String toString() {
    if (maximum != null) {
      return '$minimum - $maximum';
    } else {
      return '$minimum';
    }
  }
}
