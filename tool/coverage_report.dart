// Coverage summary tool.
//
// Parses coverage/lcov.info and excludes generated sources. The percentage is
// computed strictly from the LCOV records, i.e. from the files `flutter test`
// actually instrumented.
//
// Non-generated files under lib/ that never appear in LCOV are listed
// separately as an informational warning: `flutter test --coverage` only
// instruments libraries a test loaded, and their executable-line count cannot
// be recovered from here. They are therefore NOT part of the denominator, so
// `--min` can pass while those files remain unmeasured. Import a file from a
// test to bring it into the measured set.
//
// Usage: dart run tool/coverage_report.dart [--min <percent>] [--top <n>]
import 'dart:io';

const _excludedPrefixes = <String>['lib/generated/'];
const _excludedSuffixes = <String>['.g.dart', '.freezed.dart', '.mocks.dart'];

bool _isExcluded(String path) =>
    _excludedPrefixes.any(path.startsWith) ||
    _excludedSuffixes.any(path.endsWith);

class _FileCoverage {
  _FileCoverage(this.path);
  final String path;
  int found = 0;
  int hit = 0;
  int get missing => found - hit;
  double get percent => found == 0 ? 100 : 100 * hit / found;
}

Map<String, _FileCoverage> _parseLcov(File lcov) {
  final result = <String, _FileCoverage>{};
  _FileCoverage? current;
  for (final line in lcov.readAsLinesSync()) {
    if (line.startsWith('SF:')) {
      final path = line.substring(3).trim();
      current = result.putIfAbsent(path, () => _FileCoverage(path));
    } else if (line.startsWith('LF:') && current != null) {
      current.found = int.parse(line.substring(3).trim());
    } else if (line.startsWith('LH:') && current != null) {
      current.hit = int.parse(line.substring(3).trim());
    }
  }
  return result;
}

List<String> _libSources() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .map((f) => f.path)
    .where((p) => p.endsWith('.dart') && !_isExcluded(p))
    .toList()
  ..sort();

void main(List<String> args) {
  final lcov = File('coverage/lcov.info');
  if (!lcov.existsSync()) {
    stderr.writeln('coverage/lcov.info not found. '
        'Run: flutter test --coverage');
    exit(2);
  }

  final parsed = _parseLcov(lcov)..removeWhere((path, _) => _isExcluded(path));

  // Any lib/ source absent from lcov was never loaded by a test. It has no
  // instrumented lines, so it cannot contribute to the totals below; it is
  // reported explicitly instead of disappearing silently.
  final untracked = <String>[];
  for (final path in _libSources()) {
    if (!parsed.containsKey(path)) untracked.add(path);
  }

  final found = parsed.values.fold<int>(0, (sum, f) => sum + f.found);
  final hit = parsed.values.fold<int>(0, (sum, f) => sum + f.hit);
  final percent = found == 0 ? 0.0 : 100 * hit / found;

  stdout.writeln('Line coverage: $hit/$found = ${percent.toStringAsFixed(2)}%');
  stdout.writeln('Files measured: ${parsed.length}');
  if (untracked.isNotEmpty) {
    stdout.writeln('Files with no instrumented lines: ${untracked.length} '
        '(never loaded by a test; NOT counted in the percentage above)');
    for (final path in untracked) {
      stdout.writeln('  $path');
    }
  }

  final topIndex = args.indexOf('--top');
  if (topIndex != -1 && topIndex + 1 < args.length) {
    final n = int.parse(args[topIndex + 1]);
    final worst = parsed.values.where((f) => f.missing > 0).toList()
      ..sort((a, b) => b.missing.compareTo(a.missing));
    stdout.writeln('\nLargest gaps:');
    for (final f in worst.take(n)) {
      stdout.writeln('  ${f.missing.toString().padLeft(5)} uncovered  '
          '${f.hit}/${f.found}  ${f.path}');
    }
  }

  final minIndex = args.indexOf('--min');
  if (minIndex != -1 && minIndex + 1 < args.length) {
    final min = double.parse(args[minIndex + 1]);
    if (percent < min) {
      stderr.writeln('Coverage ${percent.toStringAsFixed(2)}% '
          'is below the required $min%');
      exit(1);
    }
  }
}
