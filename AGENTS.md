# Repository Guidelines

## Project Structure & Module Organization
- Application code sits under `lib/`, grouped by domain (`lib/features/<feature>/`) with shared utilities in `lib/shared/`, dependency wiring in `lib/core/`, and services in `lib/services/`.
- Persistence, APIs, and background jobs live in `lib/data/` and `lib/background/`; generated localization output is in `lib/generated/` and must stay untouched.
- For logging, always use the pre-configured singleton `logger` instance via `import 'package:mostro_mobile/services/logger_service.dart';`. Direct instantiation of `Logger()` is no longer permitted. Refer to `docs/LOGGING_IMPLEMENTATION.md` for detailed guidelines.
- Tests mirror the feature layout under `test/`, end-to-end flows run from `integration_test/`, and platform wrappers reside in `android/`, `ios/`, and `web/`. Additional guidance sits in `docs/`.

## Build, Test, and Development Commands
- `flutter pub get` — sync Dart dependencies after pulling or switching branches.
- `dart run build_runner build -d` — regenerate localization, mocks, and models when ARB or annotated files change.
- `flutter run` — launch the app locally; specify `-d` to target a particular device or simulator.
- `flutter analyze` — enforce the `flutter_lints` rule set; keep the tree warning-free.
- `flutter format .` — apply canonical Dart formatting before committing.
- `flutter test` and `flutter test integration_test/` — run unit/widget suites and full-stack scenarios respectively.

## Coding Style & Naming Conventions
- Follow Dart formatter defaults (two-space indentation, trailing commas) and resolve every analyzer warning.
- Name Riverpod providers `<Feature>Provider` or `<Feature>Notifier`, and keep feature assets inside their feature directory.
- Localize all user-facing strings via ARB files and access them with `S.of(context)` rather than hard-coded literals.

## Testing Guidelines
- Place unit tests beside their feature counterparts using the `*_test.dart` suffix; prefer Mockito fakes generated via `build_runner`.
- Ensure integration coverage for flows touching networking, background work, or session recovery in `integration_test/`.
- Run `flutter test` before pushing and add targeted scenarios when expanding complex logic or async workflows.

## Commit & Pull Request Guidelines
- Write concise, imperative commits, optionally prefixed with a scope (e.g., `feat:`, `docs:`), and squash to keep each change focused.
- PR descriptions should capture intent, list key changes, link tracking issues, and flag risk areas; include command output for manual tests and screenshots for UI updates.
- Keep branches rebased, and reference relevant docs or tickets when requesting review.
