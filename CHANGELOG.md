# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0+7]

### Added
- Comprehensive sats range validation for add order screen with real-time error messages
- Enhanced form validation system with centralized error handling and proper error display
- Flutter gen-l10n step to GitHub Actions CI/CD pipeline for consistent localization builds
- Proper null callback handling in MostroReactiveButton for improved button state management

### Fixed
- Submit button loading state when validation errors are present (now properly disabled)
- MostroReactiveButton null callback handling to prevent unintended loading states
- Unnecessary 'this.' qualifier removed from mostro_message.dart for code quality
- Conditional assignment optimization in mostro_storage.dart for cleaner code
- Deprecated `activeColor` parameters replaced with `activeThumbColor` in Switch widgets (4 files)
- Deprecated `synthetic-package` argument removed from l10n.yaml configuration
- Missing localization getters regenerated for validation error messages
- All Flutter analyzer issues resolved maintaining zero-issue codebase

### Changed
- Enhanced validation system now follows payment method validation pattern for consistency
- Improved button state management to prevent loading when form is invalid
- Code quality improvements with modern Flutter best practices implementation

### Removed
- Unused privacy_switch_widget.dart file (dead code cleanup)

## [1.0.0+6]

### Added
- Enhanced UI/UX for order amount input and lightning invoice screens
- Improved timeout detection system for better order state management
- Additional Latin nouns to randomized user pseudonyms (nym generation)
- Placeholder descriptions to ARB files for metadata compliance

### Fixed
- Pending status inclusion in cancellation detection logic
- Canceled order cleanup and timeout detection improvements
- Out-of-range sats amount error handling with session cleanup and retry mechanism
- Direct enum comparison for CantDoReason checks

### Changed
- Camel case formatting for compound words in codebase
- Enhanced error handling for amount validation flows

## [1.0.0+5]

### Added
- Info icon and help dialog for Lightning Address settings card
- Enhanced user guidance for Lightning Address functionality with multi-language support

### Fixed
- Order cancellation detection for orders in waiting states
- Localized cancellation notification messages
- Improved cancellation cleanup and user feedback

### Changed
- Spanish translation updated: "lightning address" to "dirección lightning"
- Enhanced Lightning Address settings UI consistency with other settings cards

## [1.0.0+4]

### Added
- Comprehensive relay URL validation with proper WebSocket protocol checking
- Real-time relay connectivity testing using direct WebSocket connections
- Loading indicators during relay validation and testing process
- Enhanced error messages for invalid relay URLs with helpful formatting hints
- Debug-only display mode for Current Trade Index Card (hidden in release builds)

### Fixed
- Relay connectivity testing now accurately detects non-existent or unreachable relays
- Invalid relay URLs (like "holahola" or "wss://xrelay.damus.io") now properly show as unhealthy
- Relay health status now reflects actual Nostr protocol compatibility
- False positive connectivity results for non-working relays eliminated
- Proper cleanup of WebSocket connections during relay testing

### Changed
- Replaced dart_nostr library-based testing with direct WebSocket implementation
- Improved relay validation logic with ws:// and wss:// protocol requirements
- Enhanced relay testing with real Nostr REQ/response message cycles
- Updated relay health checking to use actual connectivity verification
- Optimized relay testing timeouts for better user experience

### Security
- Current Trade Index Card now hidden in production builds for enhanced privacy
- Relay testing isolated from main app Nostr connections to prevent interference

## [1.0.0+3]

### Fixed
- Button text truncation issues in dialog boxes across multiple screens
- Generate New User button text wrapping and proper icon alignment
- Dialog button layouts with improved spacing and flexible sizing
- Yes/No button text cutoff in trade cancellation confirmation dialogs
- Add Relay dialog button text display issues
- Proper horizontal padding and text overflow handling in buttons

### Changed
- Enhanced dialog button implementations with Flexible widgets for better text accommodation
- Improved button padding and spacing for better visual consistency
- Updated text wrapping behavior in buttons to prevent content cutoff

## [1.0.0+2]

### Added
- Status filter dropdown to trades screen with comprehensive localization support
- Reactive order state updates in trades provider with improved UI colors
- Cooperative cancel flow and enhanced order state management
- Horizontal swipe gestures for order type switching and drawer closing
- Action-to-status mapping functionality with updated Mostro's public key
- Custom drawer overlay with slide animation and state management
- Back button handling to close drawer before exiting app
- Subscription manager for centralized Nostr event handling
- Session-based subscription management and cleanup functionality

### Changed
- Updated trades screen background color for better visual consistency
- Improved trade status filtering with OrderState integration
- Simplified trade filtering and removed unused translation keys
- Replaced DropdownButton with PopupMenuButton in status filter widget
- Enhanced session validation and error handling across data models
- Optimized session lookup for better performance

### Fixed
- Currency selection dialog state management issues
- Mounted check and provider usage in currency selector
- Rate button logic and status transitions in trade detail screen
- Error handling for status success rate functionality
- Proper action validation to reactive button widget

### Removed
- Deprecated filteredTradesProvider and updated lifecycle manager references
- Unused myActiveTrades label and related translation keys
- Duplicate and unused code in trade detail screen components

## Release Notes

### Version Naming Convention
This project uses semantic versioning with alpha/beta release phases:
- `1.0.0-alpha.x` - Alpha releases with new features and breaking changes
- `1.0.0+1-alpha-x` - Alpha builds with incremental improvements
- `1.0.0` - Stable release (planned)

### Current Development Focus
The project is actively developed with focus on:
- **Localization Excellence**: Complete multi-language support
- **UI/UX Improvements**: Modern, intuitive design patterns  
- **Code Quality**: Zero analyzer issues and best practices
- **Testing Coverage**: Comprehensive test suite
- **Documentation**: Detailed technical and user guides
- **Security**: Enhanced privacy and key management features
