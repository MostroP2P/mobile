# Repository Guidelines
## Project Structure & Module Organization
The Flutter app lives in `lib/`, organized by domain: `lib/features/<feature>/` for screens, providers, and widgets; shared utilities in `lib/shared/`; app-wide wiring in `lib/core/` and `lib/services/`; persistence and API abstractions in `lib/data/`; background work in `lib/background/`. Generated localization output sits in `lib/generated/` and should never be hand-edited. Tests mirror the feature layout under `test/`, with end-to-end flows in `integration_test/`. Mobile platform shells live in `android/`, `ios/`, and `web/`, while `assets/` stores images referenced in `pubspec.yaml`. Longer-form docs, including the architecture note, are under `docs/`.

## Build, Test, and Development Commands
Run `flutter pub get` after pulling changes to sync dependencies. Use `dart run build_runner build -d` whenever localization ARB files, mocks, or generated models change. Start the app locally with `flutter run`. Enforce static analysis via `flutter analyze`, and format the codebase with `flutter format .`. Execute fast feedback tests through `flutter test`, and cover flows that touch native bridges with `flutter test integration_test/`.

## Coding Style & Naming Conventions
Formatting follows the Dart formatter (two-space indentation, trailing commas to improve diffs). Analyzer rules come from `flutter_lints`; keep the tree at zero warnings. Name Riverpod providers `<Feature>Provider` or `<Feature>Notifier`, and place feature-specific files inside their feature directory. Keep strings in the localization ARB files and access them with `S.of(context)`; never hard-code user-facing copy. Generated files (`*.g.dart`, `*.mocks.dart`) stay untouched.

## Testing Guidelines
Add unit tests beside the code they cover, using `*_test.dart` naming, and prefer constructing fakes through Mockito via `dart run build_runner build -d`. Integration scenarios belong in `integration_test/` and should exercise full user flows (e.g., order placement with mocked relays). Before opening a review, run both `flutter analyze` and `flutter test`; include `flutter test integration_test/` when altering networking, background jobs, or session recovery.

## Commit & Pull Request Guidelines
Commits should be concise, written in the imperative mood, and optionally prefixed with a scope (`feat:`, `docs:`) as seen in history, followed by the related PR number if applicable. Squash work so each commit represents one logical change. Pull requests must describe the intent, list key changes, call out risk areas, and link tracking issues. Attach screenshots or screen recordings for UI-facing updates, and note any manual testing performed alongside the command output you ran.
