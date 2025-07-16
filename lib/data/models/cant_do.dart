import 'package:mostro_mobile/data/models/enums/cant_do_reason.dart';
import 'package:mostro_mobile/data/models/payload.dart';

class CantDo implements Payload {
  final CantDoReason cantDoReason;

  CantDo({required this.cantDoReason});

  factory CantDo.fromJson(Map<String, dynamic> json) {
    try {
      final cantDoValue = json['cant_do'];
      if (cantDoValue == null) {
        throw FormatException('Missing required field: cant_do');
      }

      String reasonString;
      if (cantDoValue is String) {
        reasonString = cantDoValue;
      } else if (cantDoValue is Map<String, dynamic>) {
        final cantDoReason = cantDoValue['cant-do'];
        if (cantDoReason == null) {
          throw FormatException('Missing required field: cant-do in cant_do object');
        }
        reasonString = cantDoReason.toString();
      } else {
        throw FormatException('Invalid cant_do type: ${cantDoValue.runtimeType}');
      }

      if (reasonString.isEmpty) {
        throw FormatException('CantDo reason cannot be empty');
      }

      return CantDo(
        cantDoReason: CantDoReason.fromString(reasonString),
      );
    } catch (e) {
      throw FormatException('Failed to parse CantDo from JSON: $e');
    }
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      type: {
        'cant-do': cantDoReason.toString(),
      }
    };
  }

  @override
  String get type => 'cant_do';
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CantDo && other.cantDoReason == cantDoReason;
  }
  
  @override
  int get hashCode => cantDoReason.hashCode;
  
  @override
  String toString() => 'CantDo(cantDoReason: $cantDoReason)';
}
