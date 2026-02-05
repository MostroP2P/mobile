# Color Analysis Report - Mostro Mobile App

**Date**: January 13, 2026
**Status**: Complete UI Color Audit
**Scope**: All color definitions and usages across the Flutter application

---

## Executive Summary

This report documents all colors and their variations used throughout the Mostro Mobile application. The analysis reveals **significant inconsistencies** in color usage, particularly with the brand's primary green color, which has **5 different variants** across the codebase.

### Critical Issues Identified

1. **Green Color Inconsistency** (CRITICAL): 5 different shades used for the same brand color
2. **Red Color Variations**: 3 different tones without clear usage guidelines
3. **Background Color Proliferation**: 5 different dark background shades
4. **Hardcoded Colors**: 8+ files with hardcoded color values instead of theme constants
5. **White Variations**: Excessive use of `Colors.white` with varying opacities

---

## 1. Centralized Color Definitions

Location: `/home/catry/mobile/lib/core/app_theme.dart`

### 1.1 Original/Legacy Colors

| Name | Hex Value | RGB | Usage Status |
|------|-----------|-----|--------------|
| `grey` | `0xFFCCCCCC` | (204, 204, 204) | ✅ Active |
| `mostroGreen` | `0xFF9CD651` | (156, 214, 81) | ✅ Active - Primary brand |
| `dark1` | `0xFF1D212C` | (29, 33, 44) | ✅ Active |
| `grey2` | `0xFF92949A` | (146, 148, 154) | ⚠️ Potentially unused |
| `yellow` | `0xFFF3CA29` | (243, 202, 41) | ✅ Active |
| `red1` | `0xFFD84D4D` | (216, 77, 77) | ⚠️ Overlaps with red2 |
| `dark2` | `0xFF303544` | (48, 53, 68) | ✅ Active |
| `cream1` | `0xFFF9F8F1` | (249, 248, 241) | ✅ Active |
| `red2` | `0xFFEF6A6A` | (239, 106, 106) | ✅ Active |
| `green2` | `0xFF84AC4D` | (132, 172, 77) | ❌ Unused legacy |

### 1.2 Background Colors

| Name | Hex Value | RGB | Purpose |
|------|-----------|-----|---------|
| `backgroundDark` | `0xFF171A23` | (23, 26, 35) | Main app background |
| `backgroundCard` | `0xFF1E2230` | (30, 34, 48) | Card containers |
| `backgroundInput` | `0xFF252A3A` | (37, 42, 58) | Input fields |
| `backgroundInactive` | `0xFF2A3042` | (42, 48, 66) | Inactive elements |
| `backgroundNavBar` | `0xFF1A1F2C` | (26, 31, 44) | Bottom navigation |

### 1.3 Text Colors

| Name | Hex Value | RGB | Purpose |
|------|-----------|-----|---------|
| `textPrimary` | `Colors.white` | (255, 255, 255) | Primary text |
| `textSecondary` | `0xFFCCCCCC` | (204, 204, 204) | Secondary text |
| `textInactive` | `0xFF8A8D98` | (138, 141, 152) | Disabled text |
| `textSubtle` | `Colors.white60` | (255, 255, 255, 60%) | Subtle text |
| `secondaryText` | `0xFFBDBDBD` | (189, 189, 189) | Alternative secondary |

### 1.4 Action Colors

| Name | Hex Value | RGB | Purpose |
|------|-----------|-----|---------|
| `buyColor` | `0xFF9DD64F` | (157, 214, 79) | Buy order actions |
| `sellColor` | `0xFFFF8A8A` | (255, 138, 138) | Sell order actions |
| `activeColor` | `0xFF9CD651` | (156, 214, 81) | Active state |
| `purpleAccent` | `0xFF764BA2` | (118, 75, 162) | Purple accent |
| `purpleButton` | `0xFF7856AF` | (120, 86, 175) | Purple buttons |

### 1.5 Status Colors

| Name | Hex Value | RGB | Purpose |
|------|-----------|-----|---------|
| `statusSuccess` | `0xFF9CD651` | (156, 214, 81) | Success states |
| `statusWarning` | `0xFFF3CA29` | (243, 202, 41) | Warning states |
| `statusError` | `0xFFEF6A6A` | (239, 106, 106) | Error states |
| `statusActive` | `0xFF9CD651` | (156, 214, 81) | Active states |
| `statusInfo` | `0xFF2A7BD6` | (42, 123, 214) | Info states |

### 1.6 Role Chip Colors

| Name | Hex Value | RGB | Purpose |
|------|-----------|-----|---------|
| `createdByYouChip` | `0xFF1565C0` | (21, 101, 192) | Orders you created |
| `takenByYouChip` | `0xFF00796B` | (0, 121, 107) | Orders you took |
| `premiumPositiveChip` | `0xFF388E3C` | (56, 142, 60) | Positive premium |
| `premiumNegativeChip` | `0xFFC62828` | (198, 40, 40) | Negative premium |

### 1.7 Status Chip Colors (Background/Text Pairs)

| Status | Background | Text | Hex Background | Hex Text |
|--------|-----------|------|----------------|----------|
| **Pending** | `0xFF854D0E` | `0xFFFCD34D` | (133, 77, 14) | (252, 211, 77) |
| **Waiting** | `0xFF7C2D12` | `0xFFFED7AA` | (124, 45, 18) | (254, 215, 170) |
| **Active** | `0xFF1E3A8A` | `0xFF93C5FD` | (30, 58, 138) | (147, 197, 253) |
| **Success** | `0xFF065F46` | `0xFF6EE7B7` | (6, 95, 70) | (110, 231, 183) |
| **Dispute** | `0xFF7F1D1D` | `0xFFFCA5A5` | (127, 29, 29) | (252, 165, 165) |
| **Settled** | `0xFF581C87` | `0xFFC084FC` | (88, 28, 135) | (192, 132, 252) |
| **Inactive** | `0xFF1F2937` | `0xFFD1D5DB` | (31, 41, 55) | (209, 213, 219) |

---

## 2. Hardcoded Colors Found in Widgets

### 2.1 Currency Selection Dialog
**File**: `lib/shared/widgets/currency_selection_dialog.dart`

| Usage | Hex Value | RGB | Should Use |
|-------|-----------|-----|------------|
| Background | `0xFF1E2230` | (30, 34, 48) | `AppTheme.backgroundCard` |
| Background alt | `0xFF252a3a` | (37, 42, 58) | `AppTheme.backgroundInput` |
| Border/accent | `0xFF8CC63F` (alpha 0.3) | (140, 198, 63) | `AppTheme.mostroGreen` |

### 2.2 Walkthrough Screen
**File**: `lib/features/walkthrough/screens/walkthrough_screen.dart`

| Usage | Hex Value | RGB | Should Use |
|-------|-----------|-----|------------|
| Text | `0xFF9aa1b6` | (154, 161, 182) | `AppTheme.textSecondary` |
| Accent | `0xFF8cc63f` | (140, 198, 63) | `AppTheme.mostroGreen` |

### 2.3 Exchange Rate Widget
**File**: `lib/shared/widgets/exchange_rate_widget.dart`

| Usage | Hex Value | RGB | Should Use |
|-------|-----------|-----|------------|
| Background | `0xFF303544` | (48, 53, 68) | `AppTheme.dark2` |

### 2.4 Home Screen
**File**: `lib/features/home/screens/home_screen.dart`

| Usage | Hex Value | RGB | Should Use |
|-------|-----------|-----|------------|
| Background | `0xFF1D212C` (used twice) | (29, 33, 44) | `AppTheme.dark1` |

### 2.5 Chat Info Buttons
**File**: `lib/features/chat/widgets/info_buttons.dart`

| Usage | Hex Value | RGB | Should Use |
|-------|-----------|-----|------------|
| Selected foreground | `0xFF1A1A1A` | (26, 26, 26) | Create constant |

### 2.6 Auth Screens

**Register**: `lib/features/auth/screens/register_screen.dart`
- Background: `0xFF1D212C` → Should use `AppTheme.dark1`

**Login**: `lib/features/auth/screens/login_screen.dart`
- Background: `0xFF1D212C` → Should use `AppTheme.dark1`

### 2.7 Add Order Screen
**File**: `lib/features/order/screens/add_order_screen.dart`

| Usage | Hex Value | RGB | Should Use |
|-------|-----------|-----|------------|
| Background | `0xFF171A23` | (23, 26, 35) | `AppTheme.backgroundDark` |
| Warning icon | `0xFFF3CA29` | (243, 202, 41) | `AppTheme.yellow` |
| Accent | `0xFF8CC63F` | (140, 198, 63) | `AppTheme.mostroGreen` |
| Card background | `0xFF1E2230` | (30, 34, 48) | `AppTheme.backgroundCard` |

### 2.8 Payment Confirmation Screen
**File**: `lib/features/order/screens/payment_confirmation_screen.dart`

| Usage | Hex Value | RGB | Should Use |
|-------|-----------|-----|------------|
| Background | `0xFF1D212C` | (29, 33, 44) | `AppTheme.dark1` |
| Card | `0xFF303544` | (48, 53, 68) | `AppTheme.dark2` |
| Success | `0xFF8CC541` | (140, 197, 65) | **⚠️ Different green!** |

### 2.9 About Screen
**File**: `lib/features/settings/about_screen.dart`

| Usage | Hex Value | RGB | Should Use |
|-------|-----------|-----|------------|
| Background | `0xFF1E2230` | (30, 34, 48) | `AppTheme.backgroundCard` |
| Button | `0xFF8CC63F` | (140, 198, 63) | `AppTheme.mostroGreen` |

### 2.10 Order Widgets

**Amount Section**: `lib/features/order/widgets/amount_section.dart`
- Green: `0xFF8CC63F` with various alpha values

**Payment Methods**: `lib/features/order/widgets/payment_methods_section.dart`
- Green: `0xFF8CC63F` with alpha 0.3

**Currency Section**: `lib/features/order/widgets/currency_section.dart`
- Green: `0xFF8CC63F` with alpha 0.3
- Purple: `0xFF764BA2` with alpha 0.3

**Order Type Header**: `lib/features/order/widgets/order_type_header.dart`
- Background: `0xFF1E2230`

### 2.11 Dispute Message Bubble
**File**: `lib/features/chat/widgets/dispute_message_bubble.dart`

| Usage | Hex Value | RGB | Should Use |
|-------|-----------|-----|------------|
| Admin blue | `0xFF1565C0` | (21, 101, 192) | `AppTheme.createdByYouChip` |

---

## 3. Colors.xxx Usage Patterns

### 3.1 White Variations (Extensive Use)

| Pattern | Occurrences | Purpose |
|---------|-------------|---------|
| `Colors.white` | 46+ | Primary text |
| `Colors.white70` | 112+ | Secondary text and icons |
| `Colors.white60` | 35+ | Tertiary text |
| `Colors.white.withValues(alpha: 0.05)` | Multiple | Borders/subtle backgrounds |
| `Colors.white.withValues(alpha: 0.1)` | Multiple | Borders and highlights |

**Recommendation**: Replace with `AppTheme.textPrimary`, `AppTheme.textSecondary`, etc.

### 3.2 Black Variations

| Pattern | Occurrences | Purpose |
|---------|-------------|---------|
| `Colors.black.withValues(alpha: 0.7)` | Multiple | Card shadows |
| `Colors.black.withValues(alpha: 0.4)` | Multiple | Button shadows |
| Various alpha values | Multiple | Overlays and shadows |

### 3.3 Other Colors.xxx Usage

| Color | Usage | Files |
|-------|-------|-------|
| `Colors.blue` | Links and clickable text | Multiple |
| `Colors.blue[900]` | Dispute messages | Chat widgets |
| `Colors.blue[300]` | Dispute messages | Chat widgets |
| `Colors.grey.shade700` | Inactive button state | Add order screen |
| `Colors.grey[700]` | Dispute UI elements | Chat widgets |
| `Colors.grey[400]` | Dispute UI elements | Chat widgets |
| `Colors.red` | Error states, badges | Multiple |
| `Colors.green` | Success feedback | Multiple |
| `Colors.amber` | Star ratings | Multiple |
| `Colors.transparent` | Background overlays | Multiple |

---

## 4. Color Inconsistencies - CRITICAL ISSUES

### 4.1 Green Variants (HIGHEST PRIORITY)

The app uses **5 DIFFERENT shades of green** that should be standardized:

| Variant | Hex Value | RGB | Difference from Brand | Files Affected |
|---------|-----------|-----|----------------------|----------------|
| `mostroGreen` | `0xFF9CD651` | (156, 214, 81) | **Reference** | app_theme.dart |
| `buyColor` | `0xFF9DD64F` | (157, 214, 79) | +1 R, 0 G, -2 B | app_theme.dart |
| Hardcoded #1 | `0xFF8CC63F` | (140, 198, 63) | -16 R, -16 G, -18 B | **~10 files** |
| Payment green | `0xFF8CC541` | (140, 197, 65) | -16 R, -17 G, -16 B | payment_confirmation |
| `green2` (legacy) | `0xFF84AC4D` | (132, 172, 77) | -24 R, -42 G, -4 B | Unused |

**Visual Comparison**:
```
mostroGreen:  ████ #9CD651 (156, 214, 81)  ← Official brand color
buyColor:     ████ #9DD64F (157, 214, 79)  ← Almost identical
Hardcoded:    ████ #8CC63F (140, 198, 63)  ← Darker, used extensively
Payment:      ████ #8CC541 (140, 197, 65)  ← Yet another variant
green2:       ████ #84AC4D (132, 172, 77)  ← Legacy, unused
```

**Impact**: This is the **most critical inconsistency** as it affects the brand's visual identity across the entire app.

**Files with Hardcoded Green** (`0xFF8CC63F`):
1. `lib/shared/widgets/currency_selection_dialog.dart`
2. `lib/features/walkthrough/screens/walkthrough_screen.dart`
3. `lib/features/order/screens/add_order_screen.dart`
4. `lib/features/order/widgets/amount_section.dart`
5. `lib/features/order/widgets/payment_methods_section.dart`
6. `lib/features/order/widgets/currency_section.dart`
7. `lib/features/settings/about_screen.dart`
8. Multiple other widget files

### 4.2 Red Variants

Three different red tones used without clear differentiation:

| Variant | Hex Value | RGB | Purpose |
|---------|-----------|-----|---------|
| `red1` | `0xFFD84D4D` | (216, 77, 77) | Legacy |
| `red2` / `statusError` | `0xFFEF6A6A` | (239, 106, 106) | Error states |
| `sellColor` | `0xFFFF8A8A` | (255, 138, 138) | Sell actions |

**Visual Comparison**:
```
red1:       ████ #D84D4D (216, 77, 77)   ← Darkest
red2:       ████ #EF6A6A (239, 106, 106) ← Medium
sellColor:  ████ #FF8A8A (255, 138, 138) ← Lightest
```

**Recommendation**: Keep `statusError` and `sellColor`, remove `red1` if unused.

### 4.3 Background Variants

Five different dark background shades create visual inconsistency:

| Variant | Hex Value | RGB | Lightness | Purpose |
|---------|-----------|-----|-----------|---------|
| `backgroundDark` | `0xFF171A23` | (23, 26, 35) | Darkest | Main background |
| `backgroundNavBar` | `0xFF1A1F2C` | (26, 31, 44) | Very dark | Nav bar |
| `dark1` | `0xFF1D212C` | (29, 33, 44) | Dark | Alt background |
| `backgroundCard` | `0xFF1E2230` | (30, 34, 48) | Medium dark | Cards |
| `backgroundInput` | `0xFF252A3A` | (37, 42, 58) | Medium | Inputs |
| `backgroundInactive` | `0xFF2A3042` | (42, 48, 66) | Light dark | Inactive |
| `dark2` | `0xFF303544` | (48, 53, 68) | Lightest | Cards/dialogs |

**Visual Scale** (Darkest → Lightest):
```
backgroundDark:     ████ #171A23 (23, 26, 35)   1
backgroundNavBar:   ████ #1A1F2C (26, 31, 44)   2
dark1:              ████ #1D212C (29, 33, 44)   3
backgroundCard:     ████ #1E2230 (30, 34, 48)   4
backgroundInput:    ████ #252A3A (37, 42, 58)   5
backgroundInactive: ████ #2A3042 (42, 48, 66)   6
dark2:              ████ #303544 (48, 53, 68)   7
```

**Recommendation**: Consolidate to 3-4 maximum background levels.

### 4.4 Purple Variants

Two purple shades without clear usage guidelines:

| Variant | Hex Value | RGB | Purpose |
|---------|-----------|-----|---------|
| `purpleAccent` | `0xFF764BA2` | (118, 75, 162) | Accent color |
| `purpleButton` | `0xFF7856AF` | (120, 86, 175) | Button color |

**Visual Comparison**:
```
purpleAccent:  ████ #764BA2 (118, 75, 162)
purpleButton:  ████ #7856AF (120, 86, 175)
```

**Recommendation**: Document when to use each variant or consolidate to one.

### 4.5 Gray/Grey Variants

Multiple gray tones with overlapping purposes:

| Variant | Hex Value | RGB | Purpose |
|---------|-----------|-----|---------|
| `grey` | `0xFFCCCCCC` | (204, 204, 204) | General gray |
| `grey2` | `0xFF92949A` | (146, 148, 154) | Alternative gray |
| `textSecondary` | `0xFFCCCCCC` | (204, 204, 204) | Secondary text |
| `textInactive` | `0xFF8A8D98` | (138, 141, 152) | Inactive text |
| `secondaryText` | `0xFFBDBDBD` | (189, 189, 189) | Alt secondary |

**Note**: `grey` and `textSecondary` are identical (`0xFFCCCCCC`).

---

## 5. Opacity/Alpha Patterns

Extensive use of `.withValues(alpha: x)` throughout the codebase:

| Alpha Value | Opacity % | Common Uses | Occurrences |
|-------------|-----------|-------------|-------------|
| 0.05 | 5% | Very subtle borders/highlights | Multiple |
| 0.1 | 10% | Subtle backgrounds/borders | Multiple |
| 0.3 | 30% | Icon backgrounds, chip backgrounds | Extensive |
| 0.5 | 50% | Disabled button states | Multiple |
| 0.6 | 60% | Subdued text (`Colors.white60`) | 35+ |
| 0.7 | 70% | Shadows, secondary text | 112+ |
| 0.85 | 85% | Overlays | Few |

**Recommendation**: Define opacity constants in `AppTheme` for consistency.

---

## 6. Theme Integration

### 6.1 Theme.of(context) Usage

**Minimal use** of Flutter's theme system:
- Only **3 instances** found in notification menu
- Most colors are hardcoded or use `AppTheme` static constants

**Recommendation**: Consider leveraging `ColorScheme` for better theme integration.

### 6.2 Gradient Usage

**Minimal gradient use**:
- Only **1 instance** found: `LinearGradient` in encrypted file message widget

---

## 7. Well-Organized Color Systems

### 7.1 Status Chip System ✅

The **only** color system that is well-organized and consistent:

```dart
// Each status has a dedicated background/text pair
Pending:  Background #854D0E → Text #FCD34D
Waiting:  Background #7C2D12 → Text #FED7AA
Active:   Background #1E3A8A → Text #93C5FD
Success:  Background #065F46 → Text #6EE7B7
Dispute:  Background #7F1D1D → Text #FCA5A5
Settled:  Background #581C87 → Text #C084FC
Inactive: Background #1F2937 → Text #D1D5DB
```

**Recommendation**: Keep this system as is - it's the best example in the codebase.

---

## 8. Recommendations

### 8.1 CRITICAL - Immediate Actions

#### Priority 1: Standardize Green Color
**Problem**: 5 different green variants damage brand consistency.

**Solution Options**:

**Option A**: Use `0xFF9CD651` (current `mostroGreen`)
- Pros: Already defined as primary brand color
- Cons: Need to update ~10+ files

**Option B**: Use `0xFF8CC63F` (most commonly hardcoded)
- Pros: Already used in most widgets
- Cons: Different from official brand color

**Recommendation**: **Choose Option A** - maintain brand color integrity.

**Action Items**:
1. Update all `0xFF8CC63F` → `AppTheme.mostroGreen`
2. Update `buyColor` from `0xFF9DD64F` → `0xFF9CD651`
3. Update payment confirmation `0xFF8CC541` → `AppTheme.mostroGreen`
4. Remove unused `green2` legacy color
5. Add documentation: "Always use `AppTheme.mostroGreen` for brand green"

**Affected Files** (Priority Order):
```
1. lib/features/order/widgets/amount_section.dart
2. lib/features/order/widgets/payment_methods_section.dart
3. lib/features/order/widgets/currency_section.dart
4. lib/features/order/screens/add_order_screen.dart
5. lib/features/order/screens/payment_confirmation_screen.dart
6. lib/shared/widgets/currency_selection_dialog.dart
7. lib/features/walkthrough/screens/walkthrough_screen.dart
8. lib/features/settings/about_screen.dart
```

#### Priority 2: Consolidate Background Colors
**Problem**: 7 different dark backgrounds create subtle inconsistencies.

**Solution**: Reduce to 4 levels:
```dart
// Proposed hierarchy
backgroundDark     → 0xFF171A23  // Darkest - main app background
backgroundCard     → 0xFF1E2230  // Cards and containers
backgroundInput    → 0xFF252A3A  // Input fields and interactive
backgroundElevated → 0xFF303544  // Elevated/modal surfaces
```

**Action Items**:
1. Map existing colors to new hierarchy
2. Remove: `backgroundNavBar`, `backgroundInactive`, `dark1`, `dark2`
3. Update all hardcoded background values
4. Document usage guidelines

#### Priority 3: Replace Hardcoded Colors
**Problem**: 8+ files have hardcoded colors instead of theme constants.

**Action Items**:
1. Create script to find all `Color(0xFF...)` instances
2. Replace with appropriate `AppTheme.*` constants
3. Add linting rule to prevent future hardcoding

### 8.2 MEDIUM - Quality Improvements

#### Red Color Consolidation
**Current**: 3 red variants (`red1`, `red2`, `sellColor`)

**Recommendation**:
```dart
// Keep these
statusError  → 0xFFEF6A6A  // For error messages
sellColor    → 0xFFFF8A8A  // For sell actions

// Remove if unused
red1         → Delete if no usages found
```

#### White Color Standardization
**Problem**: Excessive use of `Colors.white` with varying opacities.

**Solution**: Define text color hierarchy:
```dart
// In AppTheme
static const textPrimary   = Colors.white;          // 100%
static const textSecondary = Color(0xFFCCCCCC);     // ~80%
static const textTertiary  = Color(0xFF9A9DA8);     // ~60%
static const textDisabled  = Color(0xFF6B6E7A);     // ~40%
```

**Action Items**:
1. Replace `Colors.white70` → `AppTheme.textSecondary`
2. Replace `Colors.white60` → `AppTheme.textTertiary`
3. Replace `Colors.white.withValues(alpha: 0.4)` → `AppTheme.textDisabled`

#### Purple Color Documentation
**Current**: Two purple variants without clear guidelines.

**Action Items**:
1. Document when to use `purpleAccent` vs `purpleButton`
2. Consider consolidating to single purple if use cases overlap

### 8.3 LOW - Maintenance Tasks

#### Remove Legacy Colors
**Candidates for removal** (verify no usages first):
- `green2` (`0xFF84AC4D`) - Appears unused
- `red1` (`0xFFD84D4D`) - May be redundant with `red2`
- `grey2` (`0xFF92949A`) - May be redundant

**Action**: Run codebase search to confirm zero usages, then delete.

#### Add Opacity Constants
**Problem**: Inconsistent alpha values scattered throughout code.

**Solution**: Define standard opacity levels:
```dart
// In AppTheme
static const double opacitySubtle = 0.05;   // Borders
static const double opacityLight  = 0.1;    // Backgrounds
static const double opacityMild   = 0.3;    // Icons
static const double opacityMedium = 0.5;    // Disabled
static const double opacityStrong = 0.7;    // Shadows
```

---

## 9. Implementation Plan

### Phase 1: Critical Green Standardization (Week 1)
**Goal**: Fix brand color inconsistency

**Tasks**:
1. ✅ Decision: Use `0xFF9CD651` as standard green
2. ⬜ Update `AppTheme.buyColor` to match `mostroGreen`
3. ⬜ Replace all `0xFF8CC63F` instances (8 files)
4. ⬜ Replace `0xFF8CC541` in payment confirmation
5. ⬜ Run `flutter analyze` to verify no issues
6. ⬜ Visual testing on all affected screens
7. ⬜ Delete unused `green2` after verification

**Success Criteria**: Zero hardcoded green values, single brand color throughout app.

### Phase 2: Background Color Consolidation (Week 2)
**Goal**: Simplify background color hierarchy

**Tasks**:
1. ⬜ Define 4-level background hierarchy
2. ⬜ Create migration map (old → new)
3. ⬜ Update all widget files
4. ⬜ Remove deprecated background constants
5. ⬜ Document background usage guidelines
6. ⬜ Visual consistency check

**Success Criteria**: 4 background colors maximum, clear usage documentation.

### Phase 3: Hardcoded Color Elimination (Week 3)
**Goal**: Move all colors to theme constants

**Tasks**:
1. ⬜ Search for all remaining `Color(0xFF...)` instances
2. ⬜ Create missing theme constants as needed
3. ⬜ Replace hardcoded values
4. ⬜ Add linting rule: `avoid_hardcoded_colors`
5. ⬜ Code review all changes

**Success Criteria**: Zero hardcoded colors except in `app_theme.dart`.

### Phase 4: Text Color Standardization (Week 4)
**Goal**: Replace Colors.white variations

**Tasks**:
1. ⬜ Define complete text color hierarchy
2. ⬜ Replace `Colors.white70` instances (112+)
3. ⬜ Replace `Colors.white60` instances (35+)
4. ⬜ Replace dynamic alpha variations
5. ⬜ Update documentation

**Success Criteria**: All text colors use `AppTheme.text*` constants.

### Phase 5: Cleanup & Documentation (Week 5)
**Goal**: Remove legacy, document decisions

**Tasks**:
1. ⬜ Verify and remove unused colors
2. ⬜ Add usage comments to all `AppTheme` colors
3. ⬜ Create color usage guidelines document
4. ⬜ Add examples to style guide
5. ⬜ Final `flutter analyze` check

**Success Criteria**: Clean codebase, comprehensive documentation.

---

## 10. Color Usage Guidelines (Proposed)

### 10.1 Brand Colors

```dart
// PRIMARY - Use for all brand-related elements
AppTheme.mostroGreen  → Buttons, accents, active states, buy actions

// SECONDARY - Status indicators
AppTheme.yellow       → Warnings, pending states
AppTheme.sellColor    → Sell actions, destructive actions
```

### 10.2 Background Hierarchy

```dart
// Level 0: Main background
AppTheme.backgroundDark      → Main screen background

// Level 1: Elevated surfaces
AppTheme.backgroundCard      → Cards, list items

// Level 2: Interactive elements
AppTheme.backgroundInput     → Text inputs, search bars

// Level 3: Modal surfaces
AppTheme.backgroundElevated  → Dialogs, bottom sheets
```

### 10.3 Text Hierarchy

```dart
// Primary: Most important text
AppTheme.textPrimary    → Headlines, primary content

// Secondary: Supporting text
AppTheme.textSecondary  → Descriptions, labels

// Tertiary: Subtle text
AppTheme.textTertiary   → Hints, timestamps

// Disabled: Inactive text
AppTheme.textDisabled   → Disabled inputs, inactive states
```

### 10.4 Status Colors

```dart
// Use dedicated status colors for semantic meaning
AppTheme.statusSuccess  → Completed actions
AppTheme.statusWarning  → Warnings, pending
AppTheme.statusError    → Errors, failures
AppTheme.statusInfo     → Informational messages
```

---

## 11. Testing Checklist

### Before Refactoring
- [ ] Document current color for each affected component
- [ ] Take screenshots of all screens for comparison
- [ ] Backup current theme file
- [ ] Create feature branch: `feat/color-standardization`

### During Refactoring
- [ ] Update colors file-by-file (not all at once)
- [ ] Run `flutter analyze` after each file
- [ ] Visual test each screen after changes
- [ ] Test both light and dark modes (if applicable)
- [ ] Test with different screen sizes

### After Refactoring
- [ ] Side-by-side screenshot comparison
- [ ] Verify brand consistency across all screens
- [ ] Performance testing (ensure no degradation)
- [ ] Accessibility testing (contrast ratios)
- [ ] Final `flutter analyze` with zero issues
- [ ] Code review before merge

---

## 12. Maintenance Rules

### DO ✅
- Always use `AppTheme.*` constants for colors
- Define new colors in `app_theme.dart` before using
- Use semantic names (e.g., `statusError` not `red2`)
- Document color purpose in comments
- Group related colors together
- Use `const` for all color definitions

### DON'T ❌
- Hardcode `Color(0xFF...)` anywhere except `app_theme.dart`
- Use `Colors.white70` or `Colors.white60` - use theme constants
- Create multiple shades of same color without clear purpose
- Use hex values directly in widget code
- Copy hex codes between files

### When Adding New Colors
1. Define in `AppTheme` with clear semantic name
2. Add usage comment
3. Group with related colors
4. Update this documentation
5. Add example usage

---

## 13. Metrics

### Current State
- **Total Color Definitions**: 50+ in `AppTheme`
- **Hardcoded Colors**: 20+ instances across 8 files
- **Green Variants**: 5 different shades
- **Red Variants**: 3 different shades
- **Background Variants**: 7 different shades
- **Files Needing Refactor**: 8 priority files

### Target State
- **Total Color Definitions**: ~35 (remove redundant)
- **Hardcoded Colors**: 0 (except in `app_theme.dart`)
- **Green Variants**: 1 (standard brand green)
- **Red Variants**: 2 (error + sell)
- **Background Variants**: 4 (clear hierarchy)
- **Files Needing Refactor**: 0

---

## 14. Appendix

### A. All Files with Hardcoded Colors

```
Priority Files (Green variants):
1. lib/features/order/widgets/amount_section.dart
2. lib/features/order/widgets/payment_methods_section.dart
3. lib/features/order/widgets/currency_section.dart
4. lib/features/order/screens/add_order_screen.dart
5. lib/features/order/screens/payment_confirmation_screen.dart
6. lib/shared/widgets/currency_selection_dialog.dart
7. lib/features/walkthrough/screens/walkthrough_screen.dart
8. lib/features/settings/about_screen.dart

Other Files:
9. lib/shared/widgets/exchange_rate_widget.dart
10. lib/features/home/screens/home_screen.dart
11. lib/features/chat/widgets/info_buttons.dart
12. lib/features/auth/screens/register_screen.dart
13. lib/features/auth/screens/login_screen.dart
14. lib/features/chat/widgets/dispute_message_bubble.dart
```

### B. Search Patterns for Cleanup

```bash
# Find all hardcoded colors
grep -r "Color(0x" lib/ --exclude-dir=generated

# Find all Colors.white variations
grep -r "Colors.white[0-9]" lib/

# Find all withValues(alpha:
grep -r "withValues(alpha:" lib/

# Find specific green variants
grep -r "0xFF8CC63F" lib/
grep -r "0xFF9DD64F" lib/
grep -r "0xFF8CC541" lib/
```

### C. Color Comparison Tool

Visual hex comparison for quick reference:

| Name | Hex | R | G | B | Brightness |
|------|-----|---|---|---|------------|
| backgroundDark | #171A23 | 23 | 26 | 35 | 10% |
| backgroundCard | #1E2230 | 30 | 34 | 48 | 13% |
| dark2 | #303544 | 48 | 53 | 68 | 19% |
| mostroGreen | #9CD651 | 156 | 214 | 81 | 69% |
| hardcoded green | #8CC63F | 140 | 198 | 63 | 62% |

---

## 15. Changelog

| Date | Version | Changes |
|------|---------|---------|
| 2026-01-13 | 1.0.0 | Initial color analysis report |

---

## 16. References

- Flutter Color Documentation: https://api.flutter.dev/flutter/dart-ui/Color-class.html
- Material Design Color System: https://m3.material.io/styles/color/system/overview
- App Theme File: `/home/catry/mobile/lib/core/app_theme.dart`

---

**Report Generated**: January 13, 2026
**Total Analysis Time**: Comprehensive codebase scan
**Files Analyzed**: 100+ widget and screen files
**Priority Level**: CRITICAL (brand consistency affected)
