# Mutation Testing

## What is mutation testing?

Mutation testing evaluates the **quality of your test suite** by introducing small changes (mutations) to the source code and checking whether the tests detect them.

### How it works

1. **Generate mutants**: The tool creates modified versions of the code with small changes:
   - Change `==` to `!=`
   - Change `>` to `>=`
   - Remove lines of code
   - Flip `true`/`false` conditions
   - Change literal values

2. **Run tests**: All tests run against each mutated version

3. **Measure survival**:
   - ✅ **Killed mutant** → Test failed → Good! Tests detected the artificial bug
   - ❌ **Survived mutant** → Test passed → Bad! Tests did not catch the change

### Mutation score

```text
Score = (Killed mutants / Total mutants) × 100
```

| Score | Rating | Meaning |
|-------|--------|---------|
| >80%  | A - Excellent | Tests catch most bugs |
| >60%  | B - Good | Solid coverage with some gaps |
| >40%  | C - Acceptable | Room for improvement |
| >20%  | D - Needs work | Many untested code paths |
| >0%   | E - Critical | Tests are ineffective |

## Why mutation testing for Mostro Mobile?

Mostro Mobile is a **P2P Bitcoin trading application with critical security requirements**. High-quality tests are essential for ensuring user fund safety and platform reliability.

### Benefits

1. **Verify test quality**: Measures whether tests actually validate behavior, not just execute code
2. **Detect weak tests**: Finds tests that "cover" code but don't verify correctness
3. **Force better assertions**: Encourages specific, strict assertions instead of generic ones
4. **Find edge cases**: Surviving mutants often reveal untested boundary conditions
5. **Living documentation**: Documents what behavior is actually tested
6. **CI integration**: Can fail builds if mutation score drops below threshold

### Critical areas for Mostro Mobile

- **Key management**: `lib/services/key_derivator.dart` — Private key handling
- **NWC service**: `lib/services/nwc/` — Lightning wallet connections
- **Order logic**: `lib/features/order/` — Trading logic
- **Auth**: `lib/features/auth/` — Authentication and sessions
- **Disputes**: `lib/features/disputes/` — Dispute resolution

## Tool

We use [`mutation_test`](https://pub.dev/packages/mutation_test) (v1.8.0+), a Dart-native mutation testing tool that works with any test command.

## Running locally

### Full mutation test (all configured files)

```bash
dart run mutation_test mutation_test.yaml
```

### Single file

```bash
dart run mutation_test lib/services/key_derivator.dart
```

### Incremental (only changed files since last commit)

```bash
dart run mutation_test $(git diff --name-only HEAD~1 -- 'lib/**/*.dart' | grep -v '_test.dart$' | grep -v '.g.dart$' | tr '\n' ' ')
```

### With coverage data (faster — skips uncovered lines)

```bash
flutter test --coverage
dart run mutation_test mutation_test.yaml --coverage coverage/lcov.info
```

## Reports

Reports are generated in `mutation-test-report/` as HTML files. Open `mutation-test-report/mutation-test-report.html` in a browser to explore:

- Per-file mutation scores
- Surviving mutants highlighted in red (click to see the mutation)
- Quality ratings (A-E scale)

```bash
open mutation-test-report/mutation-test-report.html    # macOS
start mutation-test-report/mutation-test-report.html   # Windows
xdg-open mutation-test-report/mutation-test-report.html # Linux
```

Or simply open the file in your preferred browser.

### Example output

```text
Found 45 mutations in 5 source files!

lib/services/key_derivator.dart: 12 mutations
  ✅ 10 killed (83.3%)
  ❌ 2 survived (16.7%)

lib/features/auth/auth_service.dart: 8 mutations
  ✅ 8 killed (100%)

Results:
  Total: 45 mutations
  Killed: 40 (88.9%)
  Survived: 5 (11.1%)
  Quality: B - Good
```

## CI Integration

After copying `docs/ci/mutation-testing.yaml` to `.github/workflows/mutation-testing.yaml`,
the GitHub Actions workflow runs:

1. **Full baseline** on pushes to `main` and weekly (Monday 6:00 UTC)
2. **Incremental** on PRs (only changed source files)

Both jobs are **non-blocking** initially (`continue-on-error: true`). To enforce a minimum mutation score, set the `failure` threshold in `mutation_test.yaml`:

```yaml
threshold:
  failure: 60
```

## Configuration

The `mutation_test.yaml` file controls:

- **Which files to mutate**: `targets` and `exclude` patterns
- **Test command**: `flutter test` (with 120s timeout)
- **Exclusion patterns**: Generated files, mocks, annotations
- **Quality thresholds**: Rating scale and failure threshold

### Adding more source directories

Edit `mutation_test.yaml` to include more targets as test coverage grows:

```yaml
targets:
  lib/services/**
  lib/features/order/**
  lib/features/auth/**
```

## Gradual improvement plan

### 1. Establish baseline

```bash
dart run mutation_test mutation_test.yaml
```

Note the current mutation score.

### 2. Set initial threshold

```yaml
threshold:
  failure: 50  # Start conservative
  rating: C
```

### 3. Fix surviving mutants (priority by critical areas)

**Key management:**
- `lib/services/key_derivator.dart`
- `lib/data/repositories/auth_repository.dart`

**NWC service:**
- `lib/services/nwc/` (all files)

**Order logic:**
- `lib/features/order/models/`
- `lib/features/order/providers/`

**Auth:**
- `lib/features/auth/notifiers/`
- `lib/features/auth/providers/`

### 4. Increase threshold gradually

Each sprint, increase the threshold by 5%:

```text
Sprint 1: 50%
Sprint 2: 55%
Sprint 3: 60%
...
Target: 80% for security-critical modules
```

## Tips for better results

### 1. Specific tests > generic tests

**Bad:**

```dart
test('creates order', () {
  final order = Order(...);
  expect(order, isNotNull);  // Only checks not null
});
```

**Good:**

```dart
test('creates order with correct fields', () {
  final order = Order(
    id: 'abc123',
    amount: 1000,
  );
  expect(order.id, equals('abc123'));
  expect(order.amount, equals(1000));
  expect(order.status, equals(OrderStatus.waiting));
});
```

### 2. Test boundary conditions

```dart
test('validates amount - zero', () {
  expect(() => Order(amount: 0), throwsException);
});

test('validates amount - negative', () {
  expect(() => Order(amount: -100), throwsException);
});

test('validates amount - positive', () {
  expect(() => Order(amount: 1), returnsNormally);
});
```

### 3. Test error paths

Don't just test the happy path:

```dart
test('handles network error', () async {
  when(mockApi.fetchOrder(any)).thenThrow(SocketException('No connection'));

  final result = await getOrderUseCase.execute();

  expect(result, isError);
  expect(result.error, isA<NetworkError>());
});
```

### 4. Test state transitions

For stateful widgets:

```dart
test('transitions from loading to success', () {
  final tester = TestBinding();
  tester.pumpWidget(MyWidget());

  expect(find.text('Loading'), findsOneWidget);

  tester.pump();

  expect(find.text('Success'), findsOneWidget);
  expect(find.text('Loading'), findsNothing);
});
```

## Troubleshooting

### "No tests found" error

Make sure:
1. You have tests in `test/`
2. Files end with `_test.dart`
3. `flutter test` passes when run manually

### High execution time

- Use coverage: `dart run mutation_test --coverage coverage/lcov.info`
- Reduce targets: `dart run mutation_test lib/services/`
- Increase timeout: `timeout: 180` in mutation_test.yaml

### "Mutation score too low" in CI

1. Check the HTML report for surviving mutants
2. Add tests for critical lines
3. Increase the threshold gradually (5% per sprint)

## References

- [mutation_test on pub.dev](https://pub.dev/packages/mutation_test) — Official Dart package
- [Mutation Testing on Wikipedia](https://en.wikipedia.org/wiki/Mutation_testing) — Theoretical concepts
- [Stryker - Industry standard](https://stryker-mutator.io/) — Mutation testing for JS
- [Issue #506](https://github.com/MostroP2P/mobile/issues/506) — Tracking issue for Mostro Mobile
- [Choke mutation testing PR](https://github.com/grunch/choke/pull/39) — Similar implementation
