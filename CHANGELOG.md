# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
