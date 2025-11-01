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

### Essential Commands for Code Changes
- **`flutter analyze`** - ✅ **ALWAYS run after any code change** - Mandatory before commits
- **`flutter test`** - ✅ **ALWAYS run after any code change** - Mandatory before commits  
- **`dart run build_runner build -d`** - 🟡 **Only when code generation needed** (models, providers, mocks, localization)
- **`flutter test integration_test/`** - 🟡 **Only for significant changes** (core services, main flows)

## Architecture Overview

### State Management: Riverpod
- Uses **Riverpod** for dependency injection and state management
- Providers are organized by feature in `features/{feature}/providers/`
- **Notifier pattern** for complex state logic (authentication, order management)
- Notifiers encapsulate business logic and expose state via providers
- **SubscriptionManager Enhancement**: Includes manual initialization (`_initializeExistingSessions()`) to prevent orders getting stuck in previous states after app restart - protected by regression test

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

### Relay Management System
- **Automatic Sync**: Real-time synchronization with Mostro instance relay lists via kind 10002 events
- **Manual Addition**: Users can add custom relays with strict validation (wss://, domains only, connectivity required)
- **Instance Validation**: Author pubkey checking prevents relay contamination between Mostro instances  
- **Two-tier Testing**: Nostr protocol + WebSocket connectivity validation
- **Memory Safety**: Isolated test instances protect main app connectivity during validation
- **Dual Storage Strategy**: Mostro/default relays stored in `settings.relays`, user relays stored in `settings.userRelays` with full metadata preservation
- **Source Tracking**: Relays tagged by source (user, mostro, default) for appropriate handling and storage strategy
- **Smart Re-enablement**: Manual relay addition automatically removes from blacklist, Mostro relay re-activation removes from blacklist during sync
- **URL Normalization**: All relay URLs normalized by removing trailing slashes to ensure consistent matching
- **Implementation**: Located in `features/relays/` with core logic in `RelaysNotifier`

#### Manual Relay Addition
- Users can manually add relays via `addRelayWithSmartValidation()` method
- Five sequential validations: URL normalization, duplicate check, domain validation, connectivity testing, blacklist management  
- Security requirements: Only wss:// protocol, domain-only (no IP addresses), mandatory connectivity test
- Smart URL handling: Auto-adds "wss://" prefix if missing
- Source tracking: Manual relays marked as `RelaySource.user`
- Blacklist override: Manual addition automatically removes relay from blacklist

#### Dual Storage Architecture
- **Active Storage**: `settings.relays` contains active relay list used by NostrService
- **Metadata Storage**: `settings.userRelays` preserves complete JSON metadata for user relays
- **Lifecycle Management**: `removeRelayWithBlacklist()` adds Mostro/default relays to blacklist, `removeRelay()` permanently deletes user relays
- **Storage Synchronization**: `_saveRelays()` method synchronizes both storage locations

#### Instance Isolation
- Author pubkey validation prevents relay contamination between different Mostro instances
- Subscription cleanup on instance switching via `unsubscribeFromMostroRelayList()`
- State cleanup removes old Mostro relays when switching instances via `_cleanMostroRelaysFromState()`

#### Relay Validation System  
- Two-tier connectivity testing: Primary Nostr protocol test (REQ/EVENT/EOSE), WebSocket fallback
- Domain-only policy: IP addresses completely rejected
- URL normalization: Trailing slash removal prevents duplicate entries
- Instance-isolated testing: Test connections don't affect main app connectivity

## App Initialization Process

### Initialization Sequence
The app follows a specific initialization order in `appInitializerProvider`:

1. **NostrService Initialization**: Establishes WebSocket connections to configured relays
2. **KeyManager Initialization**: Loads cryptographic keys from secure storage  
3. **SessionNotifier Initialization**: Loads active trading sessions from Sembast database
4. **SubscriptionManager Creation**: Registers session listeners with `fireImmediately: false`
5. **Background Services Setup**: Configures notification and sync services
6. **Order Notifier Initialization**: Creates individual order managers for active sessions

### Critical Timing Requirements
- SessionNotifier must complete initialization before SubscriptionManager setup
- SubscriptionManager uses `fireImmediately: false` to prevent premature execution
- Proper sequence ensures orders appear consistently in UI across app restarts

## Timeout Detection & Orphan Session Prevention

### Overview

Comprehensive system that prevents orphan sessions and detects order timeouts through dual protection mechanisms: 10-second cleanup timers and real-time timeout detection via public events.

### Orphan Session Prevention

#### **10-Second Cleanup Timer**
Automatic cleanup system that prevents sessions from becoming orphaned when Mostro instances are unresponsive:

**Order Taking Protection**:
- **Activation**: Started automatically when users take orders (`takeSellOrder`, `takeBuyOrder`)
- **Purpose**: Prevents orphan sessions when Mostro doesn't respond within 10 seconds
- **Cleanup**: Deletes session, shows localized notification, navigates to order book
- **Cancellation**: Timer automatically cancelled when any response received from Mostro
- **Implementation**: `AbstractMostroNotifier.startSessionTimeoutCleanup()` method in `abstract_mostro_notifier.dart`

**Order Creation Protection**:
- **Activation**: Started automatically when users create orders (`AddOrderNotifier.submitOrder`)
- **Purpose**: Prevents orphan sessions when Mostro doesn't respond to new order creation within 10 seconds
- **Cleanup**: Deletes temporary session, shows localized notification, navigates to order book
- **Cancellation**: Timer automatically cancelled when any response received from Mostro
- **Implementation**: `AbstractMostroNotifier.startSessionTimeoutCleanupForRequestId()` method in `abstract_mostro_notifier.dart`

#### **Localized User Feedback**
```
English: "No response received, check your connection and try again later"
Spanish: "No hubo respuesta, verifica tu conexión e inténtalo más tarde"  
Italian: "Nessuna risposta ricevuta, verifica la tua connessione e riprova più tardi"
```

### Gift Wrap-Based Timeout Detection

#### **Detection Mechanism**
- **Direct Instructions**: Receives explicit timeout/cancellation instructions from Mostro via encrypted gift wrap messages (kind 1059)
- **No Monitoring Required**: No need to monitor public events or compare timestamps
- **Real-time**: Gift wrap messages delivered through existing SubscriptionManager system
- **Integration**: Works alongside 10-second cleanup for comprehensive protection

#### **Maker Scenario (Order Creator)**
When taker doesn't respond, Mostro sends `Action.newOrder` gift wrap:
- **Session**: Preserved (keeps order in "My Trades")
- **State**: Updated to `Status.pending` with `Action.newOrder`
- **Persistence**: Real gift wrap message automatically persisted by message storage system
- **Result**: Order remains visible and shows pending status after app restart
- **Notification**: "Your counterpart didn't respond in time"

#### **Taker Scenario (Order Taker)**
When user doesn't respond, Mostro sends `Action.canceled` gift wrap:
- **Session**: Deleted completely via `sessionNotifier.deleteSession()`
- **State**: Provider invalidated and session removed
- **Result**: Order disappears from "My Trades" and reappears in order book for retaking
- **Notification**: "Order was canceled"

### Cancellation Detection & Cleanup
When orders are canceled, Mostro sends `Action.canceled` gift wrap:
- **Detection**: Direct gift wrap instruction processing in `AbstractMostroNotifier.handleEvent()`
- **Session Cleanup**: Universal cancellation handling for both timeout and manual cancellation scenarios
- **Active Orders**: Canceled active orders keep session but update to canceled status
- **UI Behavior**: Pending/waiting orders disappear, active orders show canceled status
- **User Feedback**: Shows cancellation notification
- **Implementation**: Gift wrap handling in `abstract_mostro_notifier.dart`

### Key Implementation
- **Dual Protection**: 10-second cleanup + gift wrap instructions provide comprehensive coverage
- **Simplified Logic**: Direct instruction processing eliminates complex event monitoring
- **Timer management**: Static timer storage with proper cleanup on disposal, differentiated keys (`orderId` vs `request:requestId`)
- **Error resilience**: Timeouts and try-catch blocks prevent app hangs
- **Notifications**: Differentiated messages for maker vs taker scenarios
- **Direct Communication**: Mostro decides and instructs directly via encrypted messages
- **No Synthetic Messages**: Real gift wrap messages contain all needed information
- **Session Differentiation**: Permanent sessions (orderId) vs temporary sessions (requestId) with appropriate cleanup methods

### Testing Structure
- Unit tests in `test/` directory
- Integration tests in `integration_test/`
- Mocks generated using Mockito in `test/mocks.dart`

### Mock Files Guidelines  
- **Generated file**: `test/mocks.mocks.dart` is auto-generated by Mockito
- **File-level ignores**: Contains comprehensive ignore directives at file level
- **Regeneration**: Use `dart run build_runner build -d` to update mocks after changes
- **No manual editing**: Never manually modify generated mock files

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

### Code Comments and Documentation
- **All code comments must be in English** - No Spanish, Italian, or other languages
- Use clear, concise English for variable names, function names, and comments
- Documentation and technical explanations should be in English
- User-facing strings use localization system (`S.of(context).keyName`)

### Key Services and Components
- **MostroService** - Core business logic and Mostro protocol handling
- **NostrService** - Nostr protocol connectivity
- **Background services** - Handle notifications and background tasks
- **Key management** - Cryptographic key handling and storage
- **Exchange service** - Fiat/Bitcoin exchange rate handling

## Internationalization (i18n)

### Current Localization Setup
- **Primary languages**: English (en), Spanish (es), Italian (it)
- **ARB files location**: `lib/l10n/`
  - `intl_en.arb` - English (base language)
  - `intl_es.arb` - Spanish translations
  - `intl_it.arb` - Italian translations
- **Generated files**: `lib/generated/l10n.dart` and language-specific files
- **Usage**: Import `import 'package:mostro_mobile/generated/l10n.dart';` and use `S.of(context)!.keyName`

### Localization Best Practices
- **Always use localized strings**: Replace hardcoded text with `S.of(context)!.keyName`
- **ARB file structure**: Add new keys to all three ARB files (en, es, it)
- **Parameterized strings**: Use proper ARB metadata for strings with parameters
- **Regenerate after changes**: Run `dart run build_runner build -d` after ARB modifications
- **Context usage**: Pass BuildContext to methods that need localization

### TimeAgo Localization
- **Package**: Uses `timeago` package for relative time formatting
- **Setup**: Locales configured in `main.dart` with `timeago.setLocaleMessages()`
- **Implementation**: Custom `timeAgoWithLocale()` method in NostrEvent extension
- **Usage**: Automatically uses app's current locale for "hace X horas" vs "hours ago"

### Dynamic Countdown Timer System
- **DynamicCountdownWidget**: Intelligent countdown widget for pending orders with automatic day/hour scaling
- **Implementation**: Located in `lib/shared/widgets/dynamic_countdown_widget.dart`
- **Data Source**: Uses exact `order_expires_at` timestamps from Mostro protocol for precision
- **Dual Display Modes**:
  - **Day Scale** (>24h remaining): Shows "14d 20h 06m" format with day-based circular progress
  - **Hour Scale** (≤24h remaining): Shows "HH:MM:SS" format with hour-based circular progress
- **Automatic Transition**: Switches at exactly 24:00:00 remaining time
- **Localization**: Uses `S.of(context)!.timeLeftLabel()` for internationalized display
- **Scope**: Only for pending status orders; waiting orders use separate countdown system
- **Integration**: Shared across TakeOrderScreen and TradeDetailScreen for consistency

## Relay Synchronization System

### Overview
Comprehensive system that automatically synchronizes the app's relay list with the configured Mostro instance while providing users full control through an intelligent blacklist mechanism.

### Core Components

#### **RelayListEvent Model** (`lib/core/models/relay_list_event.dart`)
- Parses NIP-65 (kind 10002) events from Mostro instances
- Validates relay URLs (WebSocket only)
- Robust handling of different timestamp formats
- Null-safe parsing for malformed events

#### **Enhanced Relay Model** (`lib/features/relays/relay.dart`)
```dart
enum RelaySource {
  user,           // Manually added by user
  mostro,         // Auto-discovered from Mostro
  defaultConfig,  // App default relay
}

class Relay {
  final RelaySource source;
  bool get canDelete;      // User relays only
  bool get canBlacklist;   // Mostro/default relays
}
```

#### **Settings with Blacklist** (`lib/features/settings/settings.dart`)
- New `blacklistedRelays: List<String>` field
- Backward-compatible serialization
- Automatic migration for existing users

#### **RelaysNotifier** (`lib/features/relays/relays_notifier.dart`)
- **`syncWithMostroInstance()`**: Manual sync trigger
- **`removeRelayWithBlacklist(String url)`**: Smart removal with blacklisting
- **`addRelayWithSmartValidation(...)`**: Auto-removes from blacklist when user manually adds
- **`_handleMostroRelayListUpdate()`**: Filters blacklisted relays during sync

### Synchronization Flow

#### **Real-time Sync**
1. **App Launch**: Automatic subscription to kind 10002 events from configured Mostro
2. **Event Reception**: Parse relay list and filter against blacklist
3. **State Update**: Merge new relays while preserving user relays
4. **NostrService**: Automatic reconnection to updated relay list

#### **Blacklist System**
```
User removes Mostro relay → Added to blacklist → Never re-added during sync
User manually adds relay → Removed from blacklist → Works as user relay
```

### Key Features

#### **User Experience**
- **Transparent Operation**: Sync happens automatically in background
- **Full User Control**: Can permanently block problematic Mostro relays
- **Reversible Decisions**: Manual addition re-enables previously blocked relays
- **Preserved Preferences**: User relays always maintained across syncs

#### **Technical Robustness**
- **Real-time Updates**: WebSocket subscriptions for instant sync
- **Error Resilience**: Graceful fallbacks and comprehensive error handling
- **Race Protection**: Prevents concurrent sync operations
- **Logging**: Detailed logging for debugging and monitoring

#### **API Methods**
```dart
// SettingsNotifier blacklist management
Future<void> addToBlacklist(String relayUrl);
Future<void> removeFromBlacklist(String relayUrl);
bool isRelayBlacklisted(String relayUrl);

// RelaysNotifier smart operations
Future<void> removeRelayWithBlacklist(String url);
Future<void> clearBlacklistAndResync();
```

### Implementation Notes
- **Subscription Management**: Uses `SubscriptionManager` with dedicated relay list stream
- **State Persistence**: Blacklist automatically saved to SharedPreferences
- **Backward Compatibility**: Existing relay configurations preserved and migrated
- **Testing**: Comprehensive unit tests in `test/features/relays/` (currently disabled due to complex mocking requirements)

For complete technical documentation, see `RELAY_SYNC_IMPLEMENTATION.md`.

## Code Quality Standards

### Flutter Analyze
- **Target**: Zero `flutter analyze` issues
- **Deprecation handling**: Always use latest APIs (e.g., `withValues()` instead of `withOpacity()`)
- **BuildContext async gaps**: Always check `mounted` before using context after async operations
- **Imports**: Remove unused imports and dependencies
- **Immutability**: Use `const` constructors where possible

### Generated Files & Analyzer Issues
- **DO NOT** add ignore comments to generated files (`*.g.dart`, `*.mocks.dart`)
- **MockSharedPreferencesAsync warning**: File already has `// ignore_for_file: must_be_immutable`
- **duplicate_ignore warnings**: Usually caused by adding individual ignores to files with file-level ignores
- **Solution**: Regenerate files with `dart run build_runner build -d` instead of adding ignores
- **Mock files**: Never manually edit `test/mocks.mocks.dart` - it's auto-generated by Mockito

### Git Workflow
- **Branch naming**: Feature branches like `feat/feature-name`
- **Commit messages**: Descriptive messages following conventional commits
- **No Claude references**: Don't include Claude/AI references in commit messages
- **Code review**: All changes should pass `flutter analyze` before commit

## Project Context & Recent Work

### Major Features Completed

#### 1. Comprehensive Multi-Language Support
- **Complete Localization**: Added 73+ new localization keys across all screens
- **Three Languages**: Full support for English (en), Spanish (es), and Italian (it)
- **Advanced Time Formatting**: Fixed timeago package to show "hace X horas" instead of "hours ago"
- **Localized UI Components**: All user-facing strings properly internationalized
- **ARB File Management**: Organized translation files with proper metadata

#### 2. Modern UI/UX Enhancements  
- **App Icon Improvements**: Enhanced app launcher icon with proper adaptive icon support
- **Notification Icons**: Improved notification icons for better visibility
- **Card-Based Settings**: Clean, organized settings interface with visual hierarchy
- **Enhanced Account Screen**: Streamlined user profile and preferences
- **Currency Integration**: Visual currency flags for international trading
- **Relay Management**: Enhanced relay synchronization with URL normalization and settings persistence mechanisms

#### 3. Code Quality Excellence
- **Zero Analyzer Issues**: Resolved 54+ Flutter analyze issues, maintaining clean codebase
- **Modern APIs**: Updated all deprecated APIs to latest Flutter standards
- **BuildContext Safety**: Fixed async gaps with proper mounted checks
- **Code Cleanup**: Removed unused imports and dependencies
- **Const Optimization**: Added const constructors where possible

#### 4. Technical Architecture Improvements
- **Proper Timeago Localization**: Implemented locale-aware time formatting system
- **Enhanced NostrEvent Extension**: Added locale-aware methods for better UX
- **Improved Error Handling**: Better user feedback and error recovery
- **Background Services**: Reliable notification processing
- **Mock File Management**: Comprehensive documentation to prevent generated file issues

#### 5. Relay Management System Architecture
- **Dual Storage Implementation**: Mostro/default relays persist in `settings.relays` and use blacklist for deactivation, user relays persist in `settings.userRelays` with complete JSON metadata via `toJson()`/`fromJson()`
- **Differentiated Lifecycle Management**: `removeRelayWithBlacklist()` adds Mostro/default relays to blacklist for potential restoration, `removeRelay()` permanently deletes user relays from both state and storage
- **Storage Synchronization**: `_saveRelays()` method saves all active relays to `settings.relays` while separately preserving user relay metadata in `settings.userRelays`
- **URL Normalization Process**: Relay URLs undergo normalization by trimming whitespace and removing trailing slashes using `_normalizeRelayUrl()` method throughout blacklist operations in `_handleMostroRelayListUpdate()`
- **Settings Persistence Mechanism**: The Settings `copyWith()` method uses null-aware operators (`??`) to preserve existing values for selectedLanguage and defaultLightningAddress when not explicitly overridden
- **Relay Validation Protocol**: Connectivity testing follows a two-tier approach: primary Nostr protocol test (sends REQ, waits for EVENT/EOSE) via `_testNostrProtocol()`, fallback WebSocket test via `_testBasicWebSocketConnectivity()`
- **Blacklist Matching Logic**: All blacklist operations normalize both stored blacklist URLs and incoming relay URLs to ensure consistent string matching regardless of format variations

### Recent File Modifications

#### Core Infrastructure
- **`lib/main.dart`**: Timeago locale setup and app initialization
- **`lib/core/app_routes.dart`**: Navigation configuration and routing
- **`lib/core/app_theme.dart`**: UI theme and styling consistency

#### Localization System
- **`lib/l10n/*.arb`**: Complete translation files for en/es/it
- **`lib/generated/l10n*.dart`**: Generated localization classes
- **Multiple widget files**: Converted hardcoded strings to localized versions

#### UI Components
- **`lib/shared/widgets/bottom_nav_bar.dart`**: Enhanced navigation with notification badges
- **`lib/features/home/screens/home_screen.dart`**: Modern order book interface
- **`lib/features/relays/widgets/relay_selector.dart`**: Relay management interface with comprehensive validation protocol and localization support
- **Settings screens**: Card-based layout with improved accessibility

#### Notification System
- **`lib/notifications/notification_service.dart`**: Custom notification icons and improved delivery
- **Android resources**: Added notification icon assets in all density folders
- **iOS configuration**: Enhanced notification handling for iOS platform

#### Icon Assets
- **`android/app/src/main/res/`**: Adaptive icon configuration and assets
- **`pubspec.yaml`**: Updated flutter_launcher_icons configuration
- **Platform-specific assets**: Proper density support for all screen sizes

### Quality Assurance & Testing
- **Zero Flutter Analyze Issues**: Maintained throughout development
- **Comprehensive Testing**: All tests passing with proper mock implementations
- **Multi-Language Testing**: Verified localization across all supported languages
- **Platform Testing**: Validated on both Android and iOS devices
- **Performance Testing**: Ensured smooth animations and responsive UI

### Documentation Improvements
- **Enhanced CLAUDE.md**: Updated development guidelines and project context
- **New NOSTR.md**: Comprehensive technical documentation for Nostr integration
- **Updated README.md**: Modern feature overview and development guide
- **Code Documentation**: Improved inline documentation and comments

## User Preferences & Working Style

### Development Approach
- **Systematic implementation**: Break complex tasks into manageable steps
- **Quality focus**: Always run `flutter analyze` and fix issues
- **Documentation**: Update this file when making architectural changes
- **Testing**: Verify changes don't break existing functionality

### Communication Style
- **Concise responses**: Keep explanations brief and to the point
- **Code-first**: Show implementation rather than lengthy explanations
- **Problem-solving**: Focus on root cause analysis and systematic fixes
- **Best practices**: Always follow Flutter and Dart conventions

### Git Practices
- **Clean commits**: Focused, single-purpose commits
- **Descriptive messages**: Clear commit messages without AI references
- **Branch management**: Use feature branches for development
- **Push workflow**: Always test before pushing to remote

## Important File Locations

### Configuration Files
- `pubspec.yaml` - Dependencies and Flutter configuration
- `analysis_options.yaml` - Linting rules and code analysis
- `lib/core/app_routes.dart` - Navigation configuration
- `lib/core/app_theme.dart` - UI theme and styling

### Android Configuration Files
- `android/local.properties` - Flutter/Android build configuration (git-ignored; generated by CI or locally; includes `flutter.minSdkVersion=23` to prevent build.gradle auto-modifications; never commit this file or any secrets it may contain)
- `android/app/build.gradle` - Android app-specific build configuration
- `android/gradle.properties` - Gradle build properties and JVM settings
- `android/key.properties` - Keystore configuration for APK signing (generated during CI/CD)

### Key Directories
- `lib/features/` - Feature-based organization
- `lib/shared/` - Shared utilities and components
- `lib/data/` - Models, repositories, and data management
- `lib/services/` - Core services (Nostr, Mostro, etc.)
- `lib/l10n/` - Internationalization files
- `test/` - Unit and integration tests

### Relay System Files
- `lib/core/models/relay_list_event.dart` - NIP-65 event parser for kind 10002
- `lib/features/relays/relay.dart` - Enhanced relay model with source tracking
- `lib/features/relays/relays_notifier.dart` - Core relay management and sync logic
- `lib/features/relays/relays_provider.dart` - Riverpod provider configuration
- `lib/features/settings/settings.dart` - Settings model with blacklist support
- `lib/features/subscriptions/subscription_manager.dart` - Extended with relay list subscriptions
- `RELAY_SYNC_IMPLEMENTATION.md` - Complete technical documentation

### Generated Files (Don't Edit Manually)
- `lib/generated/` - Generated localization files
- `*.g.dart` - Generated Riverpod and other code
- `*.mocks.dart` - Generated Mockito mock files (especially `test/mocks.mocks.dart`)
- Platform-specific generated files

### Generated Files Best Practices
- **NEVER manually edit** generated files (`.g.dart`, `.mocks.dart`, `lib/generated/`)
- **NEVER add individual ignore comments** to generated files (e.g., `// ignore: must_be_immutable`)
- **DO NOT modify** `test/mocks.mocks.dart` - it already has file-level ignores
- **If analyzer issues exist**: Regenerate files instead of adding ignores
- **Mock files specifically**: Have file-level `// ignore_for_file: must_be_immutable` - don't add more
- **Regeneration commands**: 
  - Riverpod: `dart run build_runner build -d`
  - Mocks: `dart run build_runner build -d`
  - Localization: `flutter gen-l10n`

## Notes for Future Development

- Always maintain zero Flutter analyze issues
- Test localization changes in all supported languages
- Update this documentation when making architectural changes
- Follow existing patterns when adding new features
- Prioritize user experience and code maintainability

## Important Reminders for Claude Code

### Generated Files - CRITICAL
- **NEVER** manually edit `test/mocks.mocks.dart` or any `*.g.dart` files
- **NEVER** add `// ignore: must_be_immutable` to individual classes in generated files
- **MockSharedPreferencesAsync** already has file-level ignore - don't add more
- **duplicate_ignore warnings** are caused by adding individual ignores to files with file-level ignores
- **Solution**: Always regenerate files instead of adding ignore comments

---

**Last Updated**: October 8, 2025
**Flutter Version**: Latest stable  
**Dart Version**: Latest stable  
**Key Dependencies**: Riverpod, GoRouter, flutter_intl, timeago, dart_nostr, logger, shared_preferences

## Current Project Status

### Technical Excellence
- ✅ **Zero Flutter Analyze Issues**: Maintained clean codebase
- ✅ **Modern APIs**: All deprecated warnings resolved
- ✅ **Comprehensive Localization**: English, Spanish, Italian support
- ✅ **Enhanced UI/UX**: Modern card-based interfaces
- ✅ **Improved Icons**: App launcher and notification icons
- ✅ **Documentation**: Complete technical and user guides

### Active Features
- 🎯 **Core Trading**: Full buy/sell order management
- 💬 **Secure Chat**: NIP-59 encrypted peer-to-peer messaging  
- 🔐 **Privacy**: Hierarchical key management with trade-specific keys
- ⚡ **Lightning**: Seamless Lightning Network integration
- 🌐 **Multi-Platform**: Android and iOS native performance
- 📱 **Real-Time**: Live updates via Nostr protocol
- 🔗 **Smart Relay Management**: Automatic sync with blacklist control

### Recent Achievements
- **UI Modernization**: Complete settings and account screen redesign
- **Icon Enhancement**: Improved app launcher and notification visibility
- **Localization Excellence**: 73+ new translation keys across 3 languages
- **Code Quality**: Zero analyzer issues with modern Flutter standards
- **Documentation**: Comprehensive NOSTR.md and updated README.md
- **Relay System Architecture**: URL normalization using trailing slash removal, Settings persistence with null-aware operators, two-tier validation protocol (Nostr + WebSocket), and comprehensive multilingual support