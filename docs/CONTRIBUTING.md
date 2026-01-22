# Contributing to Mostro Mobile

Welcome! Thank you for your interest in contributing to the Mostro Mobile project. This guide will help you get started, understand the project architecture, and contribute effectively.

---

## Table of Contents
- [How to Contribute](#how-to-contribute)
- [Project Architecture Overview](#project-architecture-overview)
- [Getting Started](#getting-started)
- [Best Practices & Tips](#best-practices--tips)
- [Contact & Further Resources](#contact--further-resources)

---

## How to Contribute

We follow the standard GitHub workflow:

1. **Fork the repository**
2. **Create a new branch** for your feature or bugfix
3. **Write clear, descriptive commit messages**
4. **Push your branch** and open a Pull Request (PR)
5. **Describe your changes** thoroughly in the PR
6. **Participate in code review** and address feedback

For bug reports and feature requests, please [open an issue](https://github.com/MostroP2P/mobile/issues) with:
- Clear title and description
- Steps to reproduce (for bugs)
- Screenshots/logs if relevant

---

## Project Architecture Overview

Mostro Mobile is a Flutter app designed with modularity and maintainability in mind. Here’s a high-level overview of the architecture and key technologies:

### 1. State Management: Riverpod & Notifier Pattern
- **Riverpod** is used for dependency injection and state management.
- Providers are organized by feature, e.g., `features/order/providers/order_notifier_provider.dart`.
- The **Notifier pattern** is used for complex state logic (e.g., order submission, authentication). Notifiers encapsulate business logic and expose state via providers.
- Dedicated state providers are often used to track transient UI states, such as submission progress or error messages.

### 2. Data Persistence: Sembast
- **Sembast** is a NoSQL database used for local data persistence.
- Database initialization is handled in `shared/providers/mostro_database_provider.dart`.
- Data repositories (e.g., `data/repositories/base_storage.dart`) abstract CRUD operations and encode/decode models.
- All local data access should go through repository classes, not direct database calls.

### 3. Connectivity: NostrService
- Connectivity with the Nostr protocol is handled by `services/nostr_service.dart`.
- The `NostrService` manages relay connections, event subscriptions, and message handling.
- All Nostr-related logic should be routed through this service or its providers.

### 4. Routing: GoRouter
- Navigation is managed using **GoRouter**.
- The main router configuration is set up in `core/app.dart` (see the `goRouter` instance).
- Route definitions are centralized for maintainability and deep linking.

### 5. Internationalization (i18n)
- Internationalization is handled using the `intl` package and Flutter’s localization tools.
- Localization files are in `lib/l10n/` and generated code in `lib/generated/`.
- Use `S.of(context).yourKey` for all user-facing strings.

### 6. Other Key Patterns & Utilities
- **Background Services:** Found in `lib/background/` for handling background tasks (e.g., notifications, data sync).
- **Notifications:** Managed via `notifications/` and corresponding providers.
- **Shared Utilities:** Common widgets, helpers, and providers live in `shared/`.
- **Testing:** Tests are in the `test/` and `integration_test/` directories.

---

## Getting Started

1. **Clone the repo:**
   ```sh
   git clone https://github.com/chebizarro/mobile.git
   cd mobile
   ```
2. **Install dependencies:**
   ```sh
   flutter pub get
   ```
3. **Generate required files (CRITICAL STEP):**
   ```sh
   dart run build_runner build -d
   ```
   This generates code files (`*.g.dart`, `*.mocks.dart`) required for the app to compile. You must run this after cloning and whenever you modify files that use code generation (Riverpod providers, JSON serialization, localization files, etc.).

4. **Run the app:**
   ```sh
   flutter run
   ```
5. **Configure environment:**
   - Localization: Run `flutter gen-l10n` if you add new strings.
   - Platform-specific setup: See `README.md` for details.

6. **Testing:**
   - Unit tests: `flutter test`
   - Integration tests: `flutter test integration_test/`

7. **Linting & Formatting:**
   - Check code style: `flutter analyze`
   - Format code: `flutter format .`

---

## Best Practices & Tips

- **Follow the existing folder and provider structure.**
- **Use Riverpod for all state management.** Avoid mixing with other state solutions.
- **Encapsulate business logic in Notifiers** and expose state via providers.
- **Use repositories for all data access** (Sembast or Nostr).
- **Keep UI code declarative and side-effect free.**
- **For SnackBars, dialogs, or overlays,** always use a post-frame callback to avoid build-phase errors (see `NostrResponsiveButton` pattern).
- **Refer to existing features** (e.g., order submission, chat) for implementation examples.

---

## Generated Files & Git Workflow

### What Are Generated Files?

This project uses code generation for several purposes:
- **Riverpod providers** (`*.g.dart`)
- **JSON serialization** (`*.g.dart`)
- **Mock classes for testing** (`*.mocks.dart`)
- **Localization** (`lib/generated/`)

These files are automatically created by running:
```sh
dart run build_runner build -d
```

### Important: DO NOT Commit Generated Files

**Generated files (`*.g.dart`, `*.mocks.dart`) are in `.gitignore` and should NEVER be committed to the repository.**

#### Why?
- ✅ **Clean PRs**: Only source code changes appear in pull requests
- ✅ **No merge conflicts**: Generated files won't cause conflicts between branches
- ✅ **CI regenerates them**: GitHub Actions automatically regenerate these files during builds
- ✅ **Prevents errors**: No one can accidentally modify generated code manually

### Development Workflow

```
1. Clone repo
   └─> flutter pub get
   └─> dart run build_runner build -d  ← Generate files locally

2. Develop your feature
   └─> Make code changes
   └─> If you modify providers/models, re-run build_runner

3. Before committing
   └─> flutter analyze  ← Must pass with zero issues
   └─> flutter test     ← All tests must pass
   └─> git add          ← Add ONLY source files, NOT *.g.dart or *.mocks.dart

4. Create PR
   └─> CI automatically regenerates all files
   └─> CI runs analyze and tests
   └─> Your PR only shows actual code changes
```

### What If I See Generated Files in My Git Status?

If you see modified `*.g.dart` or `*.mocks.dart` files when running `git status`, **do NOT commit them**. They are already in `.gitignore` and should be ignored automatically. If they appear as modified, it means they were tracked before the `.gitignore` update.

Simply don't stage them:
```sh
git status           # See what changed
git add lib/...      # Add only your actual source files
git commit           # Generated files won't be included
```

### Common Scenarios

**Scenario 1: After pulling changes**
```sh
git pull
dart run build_runner build -d  # Regenerate locally
flutter run                     # App works
```

**Scenario 2: Modified a model or provider**
```sh
# Edit lib/features/settings/settings.dart
dart run build_runner build -d  # Regenerate affected files
flutter run                     # Test changes
git add lib/features/settings/settings.dart  # Add ONLY source file
git commit -m "feat: add new setting"
```

**Scenario 3: Compilation errors about missing files**
```sh
# Error: "File not found: '*.g.dart'"
dart run build_runner build -d  # Regenerate
```

---

## Contact & Further Resources

- **Main repo:** [https://github.com/MostroP2P/mobile](https://github.com/MostroP2P/mobile)
- **Questions/Help:** Open a GitHub issue or discussion
- **Docs:** See `README.md` and code comments for more details

Happy contributing!
