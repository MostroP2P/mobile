# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Development Commands

### Build and Development
- `flutter pub get` - Install dependencies
- `flutter run` - Run the application 
- `dart run build_runner build -d` - Generate required files (localization, code generation)
- `flutter test` - Run unit tests
- `flutter test integration_test/` - Run integration tests
- `flutter analyze` - Static code analysis and linting
- `flutter format .` - Format code

### Code Generation
- Run `dart run build_runner build -d` after installing dependencies or updating localization files
- This generates files needed by `flutter_intl` and other code generators

## Architecture Overview

### State Management: Riverpod
- Uses **Riverpod** for dependency injection and state management
- Providers are organized by feature in `features/{feature}/providers/`
- **Notifier pattern** for complex state logic (authentication, order management)
- Notifiers encapsulate business logic and expose state via providers

### Data Layer
- **Sembast** NoSQL database for local persistence
- Database initialization in `shared/providers/mostro_database_provider.dart`
- Repository pattern: All data access through repository classes in `data/repositories/`
- Models exported through `data/models.dart`

### Nostr Integration
- **NostrService** (`services/nostr_service.dart`) manages relay connections and messaging
- All Nostr protocol interactions go through this service
- **MostroFSM** (`core/mostro_fsm.dart`) manages order state transitions

### Navigation and UI
- **GoRouter** for navigation (configured in `core/app_routes.dart`)
- **flutter_intl** for internationalization (`l10n/` directory)
- Background services in `background/` for notifications and data sync

### Key Architecture Patterns
- Feature-based organization: `features/{feature}/{screens|providers|notifiers|widgets}/`
- Shared utilities and widgets in `shared/`
- Repository pattern for data access
- Provider pattern for dependency injection
- FSM pattern for order lifecycle management

### Testing Structure
- Unit tests in `test/` directory
- Integration tests in `integration_test/`
- Mocks generated using Mockito in `test/mocks.dart`

## Development Guidelines

### State Management
- Use Riverpod for all state management
- Encapsulate business logic in Notifiers
- Access data only through repository classes
- Use post-frame callbacks for side effects like SnackBars/dialogs

### Code Organization
- Follow existing feature-based folder structure
- Keep UI code declarative and side-effect free
- Use `S.of(context).yourKey` for all user-facing strings
- Refer to existing features (order, chat, auth) for implementation patterns

### Key Services and Components
- **MostroService** - Core business logic and Mostro protocol handling
- **NostrService** - Nostr protocol connectivity
- **Background services** - Handle notifications and background tasks
- **Key management** - Cryptographic key handling and storage
- **Exchange service** - Fiat/Bitcoin exchange rate handling