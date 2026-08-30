import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/services/logger_service.dart';

/// The logger sits on every hot path (several calls per incoming event). These
/// tests pin the cost controls: the release filter must honour the configured
/// level, the release printer must not format (no stack capture), message
/// sanitising must keep redacting, and the in-memory sink must coalesce
/// listener notifications instead of firing one per line.
void main() {
  LogEvent event(Level level) => LogEvent(level, 'msg');

  group('MostroLogFilter', () {
    test('release build honours the configured level once logging is on', () {
      // Arrange
      final filter = MostroLogFilter(verbose: false)..level = Level.warning;
      MemoryLogOutput.isLoggingEnabled = true;
      addTearDown(() => MemoryLogOutput.isLoggingEnabled = false);

      // Act / Assert
      expect(filter.shouldLog(event(Level.debug)), isFalse);
      expect(filter.shouldLog(event(Level.info)), isFalse);
      expect(filter.shouldLog(event(Level.warning)), isTrue);
      expect(filter.shouldLog(event(Level.error)), isTrue);
    });

    test('release build logs nothing while logging is off', () {
      final filter = MostroLogFilter(verbose: false)..level = Level.warning;
      MemoryLogOutput.isLoggingEnabled = false;

      expect(filter.shouldLog(event(Level.error)), isFalse);
    });

    test('verbose (debug) build lets every configured level through', () {
      final filter = MostroLogFilter(verbose: true)..level = Level.debug;
      MemoryLogOutput.isLoggingEnabled = false;

      expect(filter.shouldLog(event(Level.debug)), isTrue);
      expect(filter.shouldLog(event(Level.trace)), isFalse);
    });
  });

  group('buildLogPrinter', () {
    test('non-verbose printer does not format the event', () {
      // Arrange
      final printer = buildLogPrinter(verbose: false);

      // Act
      final lines = printer.log(event(Level.error));

      // Assert: a single blank sentinel, no message, level or stack trace.
      expect(lines, ['']);
      expect(lines.join(), isEmpty);
    });

    test('non-verbose logging still reaches the in-app Logs screen', () {
      // Arrange: the release wiring. `Logger.log` drops the event before it
      // ever reaches the output when the printer returns no lines, so an
      // empty printer would leave the Logs screen permanently blank.
      MemoryLogOutput.isLoggingEnabled = true;
      MemoryLogOutput.instance.clear();
      addTearDown(() {
        MemoryLogOutput.instance.clear();
        MemoryLogOutput.isLoggingEnabled = false;
      });

      final releaseLogger = Logger(
        printer: buildLogPrinter(verbose: false),
        output: MemoryLogOutput.instance,
        level: Level.warning,
        filter: MostroLogFilter(verbose: false)..level = Level.warning,
      );

      // Act
      releaseLogger.e('boom');
      releaseLogger.w('careful');
      releaseLogger.i('below the configured level');

      // Assert
      expect(MemoryLogOutput.instance.logCount, 2);
      final captured = MemoryLogOutput.instance.getAllLogs();
      expect(captured.map((e) => e.message), ['boom', 'careful']);
      expect(captured.map((e) => e.level), [Level.error, Level.warning]);
    });

    test('verbose printer is the pretty console printer', () {
      expect(buildLogPrinter(verbose: true), isA<PrettyPrinter>());
    });
  });

  group('cleanMessage', () {
    test('still redacts secrets and strips ANSI/box characters', () {
      final cleaned = cleanMessage(
        '\x1B[38;5;12m│ key nsec1abcdef "privateKey": "deadbeef" ┌──┐',
      );

      expect(cleaned, contains('[PRIVATE_KEY]'));
      // The final sanitizer strips quote characters, so assert on the
      // redaction marker rather than the exact JSON literal.
      expect(cleaned, contains('[REDACTED]'));
      expect(cleaned, isNot(contains('nsec1')));
      expect(cleaned, isNot(contains('deadbeef')));
      expect(cleaned, isNot(contains('│')));
    });
  });

  group('MemoryLogOutput notifications', () {
    late int notifications;
    void onChange() => notifications++;

    setUp(() {
      MemoryLogOutput.isLoggingEnabled = true;
      MemoryLogOutput.instance.clear();
      MemoryLogOutput.instance.addListener(onChange);
      notifications = 0;
    });

    tearDown(() {
      MemoryLogOutput.instance.removeListener(onChange);
      MemoryLogOutput.instance.clear();
      MemoryLogOutput.isLoggingEnabled = false;
    });

    LogEntry entry(String m) => LogEntry(
          timestamp: DateTime.now(),
          level: Level.info,
          message: m,
          service: 'test',
          line: '1',
        );

    testWidgets('a burst of entries notifies listeners once', (tester) async {
      // Act
      MemoryLogOutput.instance.addEntry(entry('a'));
      MemoryLogOutput.instance.addEntry(entry('b'));
      MemoryLogOutput.instance.addEntry(entry('c'));

      // Assert: nothing synchronously, one notification after the window
      expect(notifications, 0);
      await tester.pump(MemoryLogOutput.notifyInterval);
      expect(notifications, 1);
      expect(MemoryLogOutput.instance.logCount, 3);
    });

    testWidgets('clear notifies immediately and cancels a pending burst',
        (tester) async {
      MemoryLogOutput.instance.addEntry(entry('a'));

      MemoryLogOutput.instance.clear();

      expect(notifications, 1);
      await tester.pump(MemoryLogOutput.notifyInterval);
      expect(notifications, 1);
      expect(MemoryLogOutput.instance.logCount, 0);
    });
  });
}
