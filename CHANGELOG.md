# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v1.0.6]

### Fixed
- **GitHub Actions APK Verification** (#364): Fixed unquoted variable with spaces in file redirections that broke the signing verification step
  - Sanitized temporary filenames to avoid shell expansion issues with spaces
  - Resolved ambiguous redirect error in jarsigner verification process

## [v1.0.5]

### Added
- **Restore Orders Feature** (#355): Complete session restoration system with protocol-compliant implementation
  - Added restore-session action for recovering user sessions from Mostro
  - Implemented EmptyPayload class for proper null payload serialization
  - Support for both reputation and full privacy modes in restore requests
  - Protocol-compliant message serialization with correct wrapper keys ("restore" for Action.restore, "order" for other actions)
  - RestoreService with comprehensive session restore workflow including data cleanup and temporary subscriptions

### Changed
- **Split APK Architecture** (#360): Enhanced build system to generate architecture-specific APKs for better distribution
  - Updated GitHub Actions to build separate APKs for armeabi-v7a and arm64-v8a architectures
  - Replaced universal APK with split APKs for optimized app size per architecture
  - Enhanced APK naming convention: mostro-v{VERSION}-{architecture}.apk format
  - Improved verification process for both architecture variants using jarsigner and apksigner
- **Zapstore Distribution** (#362): Updated zapstore configuration for split APK support
  - Configured zapstore.yaml to distribute arm64-v8a APKs
  - Removed armeabi-v7a from zapstore distribution as it's not supported by the platform

## [v1.0.4]

### Added
- **Dynamic Countdown Timer System** (#354): Intelligent countdown widget with automatic day/hour scaling for pending orders
  - Uses exact `order_expires_at` timestamps from Mostro protocol for precision
  - Day scale (>24h): Shows "14d 20h 06m" format with day-based circular progress
  - Hour scale (≤24h): Shows "HH:MM:SS" format with hour-based circular progress
  - Automatic transition at 24:00:00 remaining with localized display
  - Created shared `DynamicCountdownWidget` to eliminate code duplication
  - Safe parsing with edge case handling for expired/invalid timestamps
- **Lightning Address Usage Notification** (#349): Automatic notification when configured Lightning address is used for payments
  - Detects buyerInvoice usage in order confirmation messages
  - Informs buy order makers when their configured address was automatically used
  - Integrated with existing notification system for consistent UX

### Fixed
- **Payment Method Reset** (#353): Payment methods now properly reset when fiat currency changes (#352)
  - Clears selected payment methods and custom fields on currency change
  - Prevents invalid payment methods being sent for wrong currency
- **Desktop Build Process** (#350): Resolved GitHub Actions workflow issues for Windows and Mac desktop builds

### Documentation
- **Android Signing Setup** (#347): Enhanced documentation and examples for Android APK signing configuration
  - Improved key.properties.example with detailed explanations
  - Added DEBUG_RELEASE_CONFLICT.md guide for troubleshooting build issues

## [v1.0.3]

### Added
- **Release Build Features** (#341): Chat and disputes features now enabled in production/release builds (previously debug-only)

### Fixed
- **P2P Chat Message Encryption** (#343): Restored simplified NIP-59 implementation for secure peer-to-peer messaging
- **Desktop Build Artifacts** (#344): Fixed inconsistent artifact naming for desktop builds

### Changed
- **Build Naming Convention** (#346): Standardized build artifact naming to use dash separators for consistency across all platforms
- **Debug Mode Restrictions**: Removed debug-only limitations for chat tabs and disputes view, making features fully accessible in release builds

### Documentation
- **Configuration Updates** (#345): Updated changelog and zapstore configuration file with latest project information

## [v1.0.2]

### Added
- **Desktop Application Support** (#340): Complete implementation for Windows and Mac desktop platforms
- **Dispute Chat System** (#329): Full-featured dispute chat implementation with role-specific messaging and real-time updates
- **Lightning Address Auto-Send** (#336): Automatic Lightning address transmission on add-invoice for waiting-buyer-invoice status
- **Invalid Fiat Currency Handling** (#331): Comprehensive error handling for invalid fiat currency with session cleanup and user feedback
- **Custom Mostro Public Key Support** (#315): Environment variable support for configuring custom Mostro public keys
- **Create Order Timeout Protection** (#318): Orphan session cleanup system with 10-second timeout for order creation
- **Dispute Action Button** (#323): VIEW DISPUTE button integration for orders in dispute states in order details screen
- **Admin-Canceled Dispute Status**: Enhanced dispute status handling for admin-canceled disputes with proper user notifications
- **Dispute Resolution Tracking**: Role-specific dispute resolution messages and admin assignment flow improvements

### Fixed
- **Invoice Payment Confirmation** (#337): Restored invoice payment confirmation in PayLightningInvoiceWidget
- **Exchange Rate Fetching** (#332): Fixed exchange rate fetching issue in Create Order screen for accurate pricing
- **Linux Build Configuration** (#321): Fixed Linux build with host-toolchain bootstrap in CMakeLists.txt and updated README
- **Chat Tab UI** (#320): Improved chat tab UI contrast, corrected shared key display, and fixed status badge rendering
- **Dispute Status Handling**: Case-insensitive dispute status processing with additional terminal states for admin counterparty
- **Price Type Switch UI** (#335): Enhanced visual contrast for better UX in price type switch component
- **Button Text Colors** (#333): Updated red button text color to white for improved readability
- **Switch Button Colors**: Fixed switch button color consistency across the application
- **Dispute Status Badge**: Corrected status badge display in dispute-related screens

### Changed
- **Session Deletion Timeout** (#330): Increased automatic session deletion from 36 to 72 hours for better user experience
- **NIP44 Dependency** (#338): Migrated to Mostro fork of nip44 dependency for improved protocol compatibility
- **Order Status Flow** (#327): Refactored flow from waiting to pending status for clearer state transitions
- **Dispute Status System** (#310): Complete overhaul with comprehensive localization support across all languages
- **Dispute Protocol**: Migrated dispute protocol from NIP-17 to NIP-59 for enhanced security and standardization
- **Dispute Data Handling**: Converted userDisputeDataProvider to handle async state with preserved message timestamps
- **Dispute UI Layout**: Optimized dispute chat layout with CustomScrollView and SafeArea for better mobile experience
- **Dispute Message Sorting**: Disputes now sorted by creation date in descending order for easier navigation

### Removed
- **Unused Session Peer Logic**: Removed unused session peer fallback logic in dispute chat for code cleanup
- **Mock Dispute Data**: Replaced mock dispute data with real provider implementation throughout the application
- **Debug Logging**: Removed debug logs from dispute resolution and role determination code

### Security
- **Enhanced Dispute Privacy**: Improved dispute protocol security with NIP-59 encrypted messaging
- **Session Cleanup Protection**: Automatic cleanup of orphaned sessions prevents security vulnerabilities in order creation flow

### Documentation
- **Dispute System Documentation**: Comprehensive documentation for dispute chat implementation and protocol changes
- **Desktop Platform Guide**: Setup and build instructions for Windows and Mac desktop applications
- **Linux Build Guide**: Updated README with Linux-specific build instructions and requirements

## [1.0.1]

### Added
- **Enhanced Child Order Session Management** (#311): Complete implementation of pre-emptive session creation for range order child orders with proper session lifecycle management
- **Dispute System Enhancements** (#304): Full dispute listing and management system with comprehensive UI for active orders
- **Background Push Notifications** (#297): Complete push notification integration with background support for real-time order updates
- **Orphan Session Cleanup System** (#305): 10-second timeout detection and automatic cleanup to prevent orphaned sessions when Mostro instances are unresponsive
- **Subscription Initialization Fix** (#309): Critical fix ensuring existing sessions properly load and display after app restart
- **Rating Validation System** (#312): Enhanced rating system with proper validation in notification navigation flow
- **Request ID Analysis Documentation** (#306): Comprehensive debugging documentation for troubleshooting order flow issues
- **Zapstore Distribution Support** (#302): Added zapstore spec file for alternative app distribution
- **Malawi Kwacha Currency Support** (#300): Added MWK fiat currency for Malawi users
- **Centralized Key Derivation Configuration** (#301): Improved key management architecture with centralized derivation path handling

### Fixed
- **Hold Invoice Payment Status Mapping** (#314): Correct status mapping for hold-invoice-payment-settled action to success status
- **Child Range Order Recognition** (#311): Complete fix for child orders not appearing in "My Trades" after range order completion - child orders now seamlessly link to parent sessions
- **Session Timeout Detection** (#305): Proper cleanup of orphaned sessions with 10-second timeout when no response from Mostro
- **Rating Navigation Flow** (#312): Fixed rating validation preventing proper navigation in notification flows
- **Subscription Manager Initialization** (#309): Fixed critical issue where existing sessions weren't properly loaded on app startup, causing orders to disappear from "My Trades"
- **Session State Persistence**: Enhanced session state management to prevent data loss during app lifecycle events

### Changed
- **Session Management Architecture**: Complete overhaul with pending child session tracking, proper lifecycle management, and automatic cleanup mechanisms
- **Child Order Flow**: Seamless transition from parent range orders to child orders with proper session linking and role inheritance
- **Error Handling**: Improved cant-do error processing with better user feedback and custom error messages
- **Order State Management**: Enhanced order state transitions with proper session cleanup and timeout detection
- **Subscription Management**: Improved subscription handling with automatic session-based subscription updates

### Security
- **Session Isolation**: Enhanced session cleanup to prevent data leakage between different order sessions
- **Timeout Protection**: Automatic cleanup of unresponsive sessions to prevent security vulnerabilities
- **Key Management**: Centralized key derivation path configuration with improved security practices
- **Session Privacy**: Enhanced session cleanup and timeout detection to prevent sensitive data persistence

### Documentation
- **Child Order Implementation Guide**: Comprehensive documentation of pre-emptive child order session creation system
- **Session Management Documentation**: Detailed technical documentation covering session lifecycle, cleanup, and timeout detection
- **Request ID Analysis**: Complete troubleshooting guide for debugging order flow issues
- **Technical Architecture Updates**: Enhanced system documentation including timeout detection and session cleanup processes

## [1.0.0+14]

### Added
- **Documentation System Overhaul** (#296): Complete reorganization of project documentation with improved structure
- **Protocol Documentation Integration**: Added comprehensive docs/protocol/ subtree with complete Mostro protocol specifications
- **Session and Key Management Documentation**: Detailed technical documentation for cryptographic key handling and session management
- **Automatic Relay Synchronization**: Complete relay management system with real-time sync to Mostro instances, blacklist support, and URL normalization
- **Enhanced Notifications Screen** (#257): Brand new notifications interface with improved user experience
- **Dispute System UI** (#285, #289): Enhanced dispute creation and management interface for active orders
- **Secure APK Signing for CI/CD**: Comprehensive GitHub Actions setup for secure release builds with proper certificate management
- **Enhanced Message Signing and Verification**: Comprehensive logging system for cryptographic operations with protocol compliance verification
- **Technical Architecture Documentation**: Complete system documentation including timeout detection, session cleanup, and order creation processes

### Fixed
- **Message Structure Protocol Compliance** (#295): Fixed message formatting to properly follow Mostro protocol specifications
- **Session Cleanup for Error Responses** (#287): Proper session cleanup for pending_order_exists cant-do responses
- **Range Order Release Payload** (#283): Correct next trade key handling for range order releases using proper trade pubkey instead of master key
- **Android Compilation Warnings** (#278): Resolved multiple Android build warnings and compilation issues
- **Relay Management Issues**: Fixed URL normalization, duplicate prevention, blacklist bypass prevention, and proper relay persistence
- **Key Derivation in Tests**: Added proper KeyManager stubbing for deterministic test results
- **Relay Synchronization Race Conditions**: Improved relay sync with proper deduplication and blacklist handling
- **Relay URL Normalization**: Consistent trailing slash removal and format standardization across all relay operations
- **User Relay Deletion**: Fixed duplicate keys and proper settings preservation during relay management operations

### Changed
- **Optimized Error Handling** (#292): Enhanced cant-do error processing with better user feedback and custom error messages
- **Improved Relay Selection UI**: Redesigned relay screen with switch toggles and enhanced user experience
- **Enhanced Relay Validation**: Two-tier validation system with Nostr protocol testing and WebSocket fallback connectivity checks
- **Streamlined Documentation Structure**: Reorganized technical documentation with improved accessibility and cross-references
- **Enhanced Message Logging**: Comprehensive cryptographic operation logging with verification status and debugging information

### Removed
- **Dispute Token Functionality** (#294): Removed unused dispute token system and related translations for code cleanup
- **Seller/Buyer Token System** (#293): Streamlined token handling by removing redundant seller/buyer token functionality
- **Relay Timer Leaks**: Proper cleanup of periodic timers in RelaysNotifier to prevent memory leaks
- **Instance Contamination**: Prevention of relay contamination between different Mostro instances with proper isolation

### Security
- **Enhanced Key Management**: Improved cryptographic key derivation and storage with comprehensive session isolation
- **Relay Instance Isolation**: Prevention of cross-contamination between different Mostro instances
- **Secure Build Pipeline**: Complete APK signing infrastructure with certificate fingerprint verification
- **Session Privacy**: Enhanced session cleanup and timeout detection to prevent data leakage

### Documentation
- **Complete Protocol Specifications**: Added comprehensive protocol documentation covering all Mostro operations
- **Technical Architecture Guides**: Detailed system documentation for developers including key management, session handling, and relay synchronization
- **Development Guidelines**: Updated development practices and code quality standards
- **Security Documentation**: Enhanced security practices and key management guidelines

## [1.0.0+13]

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
- Resolved the Flutter build error by updating all deprecated Switch properties
- GitHub Actions workflow simplified

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
