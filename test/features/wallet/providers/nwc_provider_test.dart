import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/features/wallet/providers/nwc_provider.dart';

void main() {
  group('NwcState', () {
    test('default state is disconnected', () {
      const state = NwcState();
      expect(state.status, NwcStatus.disconnected);
      expect(state.walletAlias, isNull);
      expect(state.balanceMsats, isNull);
      expect(state.balanceSats, isNull);
      expect(state.errorMessage, isNull);
      expect(state.supportedMethods, isEmpty);
    });

    test('balanceSats converts from millisatoshis', () {
      const state = NwcState(balanceMsats: 1500000);
      expect(state.balanceSats, 1500);
    });

    test('balanceSats truncates correctly', () {
      const state = NwcState(balanceMsats: 1999);
      expect(state.balanceSats, 1);
    });

    test('balanceSats is null when balanceMsats is null', () {
      const state = NwcState();
      expect(state.balanceSats, isNull);
    });

    test('copyWith preserves values', () {
      const state = NwcState(
        status: NwcStatus.connected,
        walletAlias: 'Test Wallet',
        balanceMsats: 5000000,
      );
      final copied = state.copyWith(balanceMsats: 10000000);
      expect(copied.status, NwcStatus.connected);
      expect(copied.walletAlias, 'Test Wallet');
      expect(copied.balanceMsats, 10000000);
    });

    test('copyWith clearWalletInfo clears wallet data', () {
      const state = NwcState(
        status: NwcStatus.connected,
        walletAlias: 'Test Wallet',
        balanceMsats: 5000000,
      );
      final cleared = state.copyWith(
        status: NwcStatus.disconnected,
        clearWalletInfo: true,
      );
      expect(cleared.walletAlias, isNull);
      expect(cleared.balanceMsats, isNull);
    });

    test('copyWith clearError clears error message', () {
      const state = NwcState(
        status: NwcStatus.error,
        errorMessage: 'Something failed',
      );
      final cleared = state.copyWith(
        status: NwcStatus.connecting,
        clearError: true,
      );
      expect(cleared.errorMessage, isNull);
    });

    test('equality works correctly', () {
      const state1 = NwcState(
        status: NwcStatus.connected,
        walletAlias: 'Wallet',
        balanceMsats: 1000,
      );
      const state2 = NwcState(
        status: NwcStatus.connected,
        walletAlias: 'Wallet',
        balanceMsats: 1000,
      );
      expect(state1, equals(state2));
    });
  });
}
