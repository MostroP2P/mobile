# Mutation Testing en Mostro Mobile

## ¿Qué es el Mutation Testing?

El mutation testing es una técnica para evaluar la **calidad de tu suite de tests** introduciendo pequeños cambios controlados (llamados "mutantes") en el código fuente y verificando si los tests detectan esos cambios.

### Cómo funciona

1. **Generar mutantes**: El tool crea versiones modificadas del código con pequeños cambios:
   - Cambiar `==` por `!=`
   - Cambiar `>` por `>=`
   - Eliminar líneas de código
   - Invertir condiciones `true`/`false`
   - Cambiar valores literales

2. **Ejecutar tests**: Se corren todos los tests contra cada versión mutante

3. **Medir supervivencia**:
   - ✅ **Mutante kill** → Test falló → ¡Bien! Los tests detectaron el "bug artificial"
   - ❌ **Mutante survived** → Test pasó → ¡Mal! Los tests no detectaron el cambio

### Mutation Score

```text
Score = (Mutantes kill / Total mutantes) × 100
```bash

| Score | Calificación | Significado |
|-------|--------------|-------------|
| >80%  | A - Excellent | Tests excellentes, capturan la mayoría de bugs |
| >60%  | B - Good      | Cobertura sólida con algunos huecos |
| >40%  | C - Acceptable| Aceptable, espacio para mejora |
| >20%  | D - Needs work| Pocos tests efectivos |
| >0%   | E - Critical  | Tests casi inefectivos |

## ¿Por qué Mutation Testing en Mostro Mobile?

Mostro Mobile es una aplicación de **comercio P2P de Bitcoin con requisitos críticos de seguridad**. Los tests de alta calidad son esenciales para garantizar la seguridad de los fondos de los usuarios y la confiabilidad de la plataforma.

### Beneficios

1. **Verify test quality**: No solo mide cobertura (líneas ejecutadas), sino que verifica que los tests realmente validen el comportamiento
2. **Detect weak tests**: Encuentra tests que "cubren" código pero no verifican corrección
3. **Forzar mejores assertions**: Incentiva assertions específicas y estrictas en vez de genéricas
4. **Find edge cases**: Mutantes supervivientes a menudo revelan condiciones de borde no testeadas
5. **Documentation viva**: Documenta qué comportamiento está realmente testeado
6. **CI integration**: Puede fallar builds si el mutation score baja del threshold

### Áreas críticas para Mostro Mobile

- **Key management**: `lib/services/key_derivator.dart` — Gestión de claves privadas
- **NWC service**: `lib/services/nwc/` — Conexiones Lightning
- **Order logic**: `lib/features/order/` — Lógica de trading
- **Auth**: `lib/features/auth/` — Autenticación y sesiones
- **Disputes**: `lib/features/disputes/` — Resolución de disputas

## Implementación

### Fase 1: Setup

#### 1. Install mutation_test package

Agrega a `pubspec.yaml` en `dev_dependencies`:

```yaml
dev_dependencies:
  mutation_test: ^1.8.0
  # ... resto de dev_dependencies
```bash

Luego ejecuta:

```bash
flutter pub get
```bash

#### 2. Create configuration file

Crea `mutation_test.yaml` en el root del proyecto:

```yaml
name: Mostro Mobile

targets:
  lib/**
  
exclude:
  - "**/*.g.dart"
  - "**/*.freezed.dart"
  - "**/*.gr.dart"
  - "**/*_test.dart"
  - "**/mock_*.dart"
  - "**/generated/**"
  - "**/generated_plugin_registrant.dart"
  
rules:
  - equality
  - relational
  - unary
  - conditional_boundary
  - literal
  - method_call
  - arithmetic
  - logical

threshold:
  failure: 0
  rating: A

test_command: flutter test

timeout: 120

output:
  - html
  - console

report_dir: mutation-test-report
```bash

#### 3. Add to .gitignore

Agrega a `.gitignore`:

```text
# Mutation testing
mutation-test-report/
*.mutation-test-cache
```bash

### Fase 2: Running localmente

#### Full mutation test (todos los archivos)

```bash
dart run mutation_test mutation_test.yaml
```bash

Esto:
- Analiza todos los archivos en `lib/`
- Excluye generated files y mocks
- Aplica todas las reglas de mutación
- Genera reporte HTML en `mutation-test-report/`

#### Single file

```bash
dart run mutation_test lib/services/key_derivator.dart
```bash

#### Incremental (solo cambios desde último commit)

```bash
dart run mutation_test $(git diff --name-only HEAD~1 -- 'lib/**/*.dart' | grep -v '_test.dart$' | grep -v '.g.dart$' | tr '\n' ' ')
```bash

#### Con coverage data (más rápido — salta líneas sin cobertura)

```bash
flutter test --coverage
dart run mutation_test mutation_test.yaml --coverage coverage/lcov.info
```bash

### Fase 3: Interpretar resultados

#### HTML Report

Ejecuta `dart run mutation_test mutation_test.yaml` y abre:

```bash
open mutation-test-report/index.html
```bash

El reporte muestra:

- **Per-file mutation scores**: Score por cada archivo
- **Surviving mutants highlighted in red**: Click para ver qué mutación sobrevivió
- **Quality ratings**: Escala A-E

#### Ejemplo de output

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
```bash

### Fase 4: CI Integration

#### Copy workflow file

```bash
cp docs/ci/mutation-testing.yaml .github/workflows/
```bash

#### Commit and push

```bash
git add docs/ci/mutation-testing.yaml .github/workflows/mutation-testing.yaml
git commit -m "ci: add mutation testing workflow

- mutation-test.yaml: configuration for mutation testing
- .github/workflows/mutation-testing.yaml: CI workflow
  * Full test on main push and weekly
  * Incremental test on PRs
  * Non-blocking initially"
git push origin feat/mutation-testing
```bash

#### Workflow details

El workflow ejecuta:

1. **Full baseline** en pushes a `main` y weekly (Monday 6:00 UTC)
2. **Incremental** en PRs (solo archivos cambiados)

Ambos jobs son **non-blocking** inicialmente (`continue-on-error: true`).

Para forzar un mutation score mínimo, edita `mutation_test.yaml`:

```yaml
threshold:
  failure: 60  # Start conservative, increase gradually
  rating: B
```bash

### Fase 5: Gradual Improvement

#### 1. Establish baseline

```bash
dart run mutation_test mutation_test.yaml
```bash

Anota el mutation score actual.

#### 2. Set initial threshold

```yaml
threshold:
  failure: [current_score]  # Por ejemplo: 50
  rating: C
```bash

#### 3. Fix surviving mutants (prioridad por areas críticas)

**Key management:**
- `lib/services/key_derivator.dart`
- `lib/data/repositories/auth_repository.dart`

**NWC service:**
- `lib/services/nwc/` (todos los archivos)

**Order logic:**
- `lib/features/order/models/`
- `lib/features/order/providers/`

**Auth:**
- `lib/features/auth/notifiers/`
- `lib/features/auth/providers/`

#### 4. Increase threshold gradually

Cada sprint, aumenta el threshold en 5%:

```bash
Sprint 1: 50%
Sprint 2: 55%
Sprint 3: 60%
...
Target: 80% para módulos críticos
```bash

## Tips para mejores resultados

### 1. Tests específicos > tests genéricos

**Bad:**
```dart
test('creates order', () {
  final order = Order(...);
  expect(order, isNotNull);  // Only checks not null
});
```bash

**Good:**
```dart
test('creates order with correct fields', () {
  final order = Order(
    id: 'abc123',
    amount: 1000,
    // ...
  );
  expect(order.id, equals('abc123'));
  expect(order.amount, equals(1000));
  expect(order.status, equals(OrderStatus.waiting));
});
```bash

### 2. Test boundary conditions

**Bad:**
```dart
test('validates amount', () {
  expect(() => Order(amount: 100), returnsNormally);
});
```bash

**Good:**
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
```bash

### 3. Test error paths

No solo tests para el happy path:

```dart
test('handles network error', () async {
  when(mockApi.fetchOrder(any)).thenThrow(SocketException('No connection'));
  
  final result = await getOrderUseCase.execute();
  
  expect(result, isError);
  expect(result.error, isA<NetworkError>());
});
```bash

### 4. Test state transitions

Para widgets con estado:

```dart
test('transitions from loading to success', () {
  final tester = TestBinding();
  tester.pumpWidget(MyWidget());
  
  expect(find.text('Loading'), findsOneWidget);
  
  tester.pump(); // Simulate state change
  
  expect(find.text('Success'), findsOneWidget);
  expect(find.text('Loading'), findsNothing);
});
```bash

## Troubleshooting

### "No tests found" error

Asegúrate de que:
1. Tienes tests en `test/`
2. Los archivos terminan en `_test.dart`
3. Ejecutas `flutter test` manualmente y pasa

### High execution time

- Usa coverage: `dart run mutation_test --coverage coverage/lcov.info`
- Reduce targets: `dart run mutation_test lib/services/`
- Aumenta timeout: `timeout: 180` en mutation_test.yaml

### "Mutation score too low" in CI

1. Revisa el reporte HTML para ver qué mutantes sobreviven
2. Agrega tests para las líneas críticas
3. Aumenta el threshold gradualmente (5% por sprint)

## Referencias

- [mutation_test on pub.dev](https://pub.dev/packages/mutation_test) — Package oficial para Dart
- [Mutation Testing on Wikipedia](https://en.wikipedia.org/wiki/Mutation_testing) — Concepts teóricos
- [Stryker - Industry standard](https://stryker-mutator.io/) — Mutation testing en JS
- [Issue #504](https://github.com/MostroP2P/mobile/issues/504) — Tracking issue para Mostro Mobile
- [Choke mutation testing PR](https://github.com/grunch/choke/pull/39) — Ejemplo de implementación exitosa

## Contact

Para preguntas sobre mutation testing en Mostro Mobile, ping a **Mostronator** 🧌
