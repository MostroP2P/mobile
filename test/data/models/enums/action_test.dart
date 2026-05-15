import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:test/test.dart';

void main() {
  group('Action enum', () {
    test('addBondInvoice wire string is "add-bond-invoice"', () {
      expect(Action.addBondInvoice.value, equals('add-bond-invoice'));
    });

    test('Action.fromString decodes bond actions without throwing', () {
      // Missing mappings crash the app when mostrod sends these.
      expect(Action.fromString('add-bond-invoice'), Action.addBondInvoice);
      expect(Action.fromString('pay-bond-invoice'), Action.payBondInvoice);
    });
  });
}
