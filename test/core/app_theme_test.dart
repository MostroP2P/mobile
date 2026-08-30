import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mostro_mobile/core/app_theme.dart';

/// `AppTheme.theme` is read on every rebuild of the root `MaterialApp`, the
/// drawer, reactive buttons and several screens. It used to be a getter that
/// built a full `ThemeData` (with ~20 `GoogleFonts` descriptor allocations)
/// on each access; the theme is immutable, so it must be built once.
void main() {
  setUpAll(() {
    // Building the theme registers GoogleFonts faces; give it a binding and
    // keep it off the network (the faces ship as bundled assets).
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('AppTheme memoization', () {
    test('theme is built once and reused across accesses', () {
      // Arrange
      final first = AppTheme.theme;

      // Act
      final second = AppTheme.theme;

      // Assert
      expect(identical(first, second), isTrue,
          reason: 'AppTheme.theme must return the same ThemeData instance');
      expect(identical(first.textTheme, second.textTheme), isTrue);
    });

    test('card and button shadows are shared instances', () {
      expect(identical(AppTheme.cardShadow, AppTheme.cardShadow), isTrue);
      expect(identical(AppTheme.buttonShadow, AppTheme.buttonShadow), isTrue);
    });
  });
}
