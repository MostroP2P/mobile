# Design System - Color Refactoring Project

**Last Updated:** January 14, 2026
**Status:** 🚧 In Progress - Phase 1 of 4 Complete

---

## Table of Contents
1. [Problem Analysis](#1-problem-analysis)
2. [Implementation Roadmap](#2-implementation-roadmap)
3. [Decision Log](#3-decision-log)
4. [Final Color Palette](#4-final-color-palette)
5. [Migration Guidelines](#5-migration-guidelines)
6. [Next Steps](#6-next-steps)

---

## 1. Problem Analysis

**⚠️ NOTE:** This section documents the **ORIGINAL STATE** before refactoring began. See Section 2 for implementation status.

This section documents the comprehensive color audit, identifying critical inconsistencies and technical debt in the color system.

### 1.1 Critical Issues Detected

#### 🔴 CRITICAL: Green Color Inconsistency
**Severity:** HIGHEST PRIORITY
**Impact:** Brand consistency compromised across entire application
**Status:** ✅ **RESOLVED IN PHASE 1**

**Problem (Original State):**
- **5 different green variants** found throughout codebase
- No single source of truth for brand color
- Visual inconsistency damages brand identity

**Variants Found:**
| Variant | Hex Value | RGB | Difference from "Official" | Usage |
|---------|-----------|-----|---------------------------|--------|
| `mostroGreen` | `0xFF9CD651` | (156, 214, 81) | Reference (official) | app_theme.dart |
| `buyColor` | `0xFF9DD64F` | (157, 214, 79) | +1 R, 0 G, -2 B | Almost identical |
| **Hardcoded #1** | `0xFF8CC63F` | (140, 198, 63) | -16 R, -16 G, -18 B | **~10 files** |
| Payment green | `0xFF8CC541` | (140, 197, 65) | -16 R, -17 G, -16 B | payment_confirmation |
| `green2` (legacy) | `0xFF84AC4D` | (132, 172, 77) | -24 R, -42 G, -4 B | Unused |

**Visual Comparison:**
```
mostroGreen:  ████ #9CD651 (156, 214, 81)  ← "Official" brand color
buyColor:     ████ #9DD64F (157, 214, 79)  ← Almost identical
Hardcoded:    ████ #8CC63F (140, 198, 63)  ← Most widely used 
Payment:      ████ #8CC541 (140, 197, 65)  ← Yet another variant
green2:       ████ #84AC4D (132, 172, 77)  ← Legacy, unused
```

**Files Affected (Hardcoded Green `#8CC63F`):**
1. `lib/features/order/widgets/amount_section.dart`
2. `lib/features/order/widgets/payment_methods_section.dart`
3. `lib/features/order/widgets/currency_section.dart`
4. `lib/features/order/screens/add_order_screen.dart`
5. `lib/features/order/widgets/order_type_header.dart`
6. `lib/shared/widgets/currency_selection_dialog.dart`
7. `lib/features/walkthrough/screens/walkthrough_screen.dart`
8. `lib/features/settings/about_screen.dart`
9. `lib/features/order/screens/payment_confirmation_screen.dart`

---

#### 🟡 MEDIUM: Red Color Proliferation
**Severity:** MEDIUM PRIORITY
**Impact:** Unclear semantic meaning, potential confusion

**Problem:**
- **3 red variants** without clear differentiation
- No documented guidelines for when to use each

**Variants Found:**
| Variant | Hex Value | RGB | Current Usage |
|---------|-----------|-----|---------------|
| `red1` | `0xFFD84D4D` | (216, 77, 77) | Legacy, possibly unused |
| `red2` / `statusError` | `0xFFEF6A6A` | (239, 106, 106) | Error states |
| `sellColor` | `0xFFFF8A8A` | (255, 138, 138) | Sell actions |

**Visual Comparison:**
```
red1:       ████ #D84D4D (216, 77, 77)   ← Darkest
red2:       ████ #EF6A6A (239, 106, 106) ← Medium
sellColor:  ████ #FF8A8A (255, 138, 138) ← Lightest (current sell)
```

**Questions to Resolve:**
- Is `red1` used anywhere? Can it be removed?
- Should sell actions use lighter or medium red?
- Should error states use same red as sell? (Currently different)

---

#### 🟣 MEDIUM: Purple Variants Without Guidelines
**Severity:** MEDIUM PRIORITY
**Impact:** Unclear usage patterns

**Problem:**
- **2 purple shades** without documented usage guidelines
- Visually similar, purpose unclear

**Variants Found:**
| Variant | Hex Value | RGB | Current Usage |
|---------|-----------|-----|---------------|
| `purpleAccent` | `0xFF764BA2` | (118, 75, 162) | Accent color (currency section) |
| `purpleButton` | `0xFF7856AF` | (120, 86, 175) | Button color (submit button) |

**Visual Comparison:**
```
purpleAccent:  ████ #764BA2 (118, 75, 162)
purpleButton:  ████ #7856AF (120, 86, 175)
```

**Questions to Resolve:**
- Can we consolidate to 1 purple?
- If keeping both, when to use each?
- Is semantic naming clear enough?

---

#### ⚫ MEDIUM: Background Color Complexity
**Severity:** MEDIUM PRIORITY (HIGH RISK due to visual impact)
**Impact:** 7 different backgrounds create subtle inconsistencies

**Problem:**
- **7 different dark background shades**
- Overly complex hierarchy
- Hard to maintain consistency

**Current Backgrounds (Darkest → Lightest):**
| Variant | Hex Value | RGB | Lightness | Current Purpose |
|---------|-----------|-----|-----------|-----------------|
| `backgroundDark` | `0xFF171A23` | (23, 26, 35) | 10% | Main background |
| `backgroundNavBar` | `0xFF1A1F2C` | (26, 31, 44) | 11% | Nav bar |
| `dark1` | `0xFF1D212C` | (29, 33, 44) | 12% | Alt background |
| `backgroundCard` | `0xFF1E2230` | (30, 34, 48) | 13% | Cards |
| `backgroundInput` | `0xFF252A3A` | (37, 42, 58) | 16% | Inputs |
| `backgroundInactive` | `0xFF2A3042` | (42, 48, 66) | 18% | Inactive |
| `dark2` | `0xFF303544` | (48, 53, 68) | 19% | Cards/dialogs |

**Visual Scale:**
```
backgroundDark:     ████ #171A23 (23, 26, 35)   Level 0 - Darkest
backgroundNavBar:   ████ #1A1F2C (26, 31, 44)   Level 1
dark1:              ████ #1D212C (29, 33, 44)   Level 2
backgroundCard:     ████ #1E2230 (30, 34, 48)   Level 3
backgroundInput:    ████ #252A3A (37, 42, 58)   Level 4
backgroundInactive: ████ #2A3042 (42, 48, 66)   Level 5
dark2:              ████ #303544 (48, 53, 68)   Level 6 - Lightest
```

**Recommendation:**
- Reduce to **4 clear levels** maximum
- Define clear semantic hierarchy
- Remove overlapping shades

**Proposed Consolidation:**
```
Level 0: backgroundDark     (#171A23) - Main screen background
Level 1: backgroundCard     (#1E2230) - Cards, elevated surfaces
Level 2: backgroundInput    (#252A3A) - Input fields, interactive
Level 3: backgroundElevated (#303544) - Modals, highest elevation

TO REMOVE/MERGE:
- backgroundNavBar → merge with backgroundDark or backgroundCard
- backgroundInactive → merge with backgroundInput
- dark1 → consolidate with existing
- dark2 → rename to backgroundElevated
```

---

#### 📝 LOW: Hardcoded Colors
**Severity:** LOW PRIORITY (but widespread)
**Impact:** Maintainability, consistency
**Status:** ✅ **RESOLVED IN PHASE 1**

**Problem (Original State):**
- **22+ hardcoded instances** across **14 files**
- Should use `AppTheme` constants instead
- Creates technical debt

**Hardcoded Colors Found (Before Phase 1):**
| Hex Value | AppTheme Equivalent | Occurrences | Files |
|-----------|---------------------|-------------|-------|
| `0xFF1D212C` | `AppTheme.dark1` | 5 | register, login, home (2x), payment_confirmation |
| `0xFF1E2230` | `AppTheme.backgroundCard` | 5 | currency_dialog, about, payment_methods, order_type_header, add_order |
| `0xFF303544` | `AppTheme.dark2` | 2 | exchange_rate, payment_confirmation |
| `0xFF171A23` | `AppTheme.backgroundDark` | 2 | add_order_screen (2x) |
| `0xFF252a3a` | `AppTheme.backgroundInput` | 2 | currency_selection_dialog (2x) |
| `0xFFF3CA29` | `AppTheme.yellow` | 2 | add_order_screen (2x) |
| `0xFF764BA2` | `AppTheme.purpleAccent` | 1 | currency_section |
| `0xFF1565C0` | `AppTheme.createdByYouChip` | 1 | dispute_message_bubble |

**✅ RESOLUTION:** All 22+ hardcoded instances were replaced with AppTheme constants in Phase 1. See Section 2.1 for details.

---

#### ⚪ LOW: Text Color Inconsistency
**Severity:** LOW PRIORITY (but high volume)
**Impact:** Subtle inconsistencies in text hierarchy

**Problem:**
- Extensive use of `Colors.white` with varying opacities
- `Colors.white70` used **112+ times**
- `Colors.white60` used **35+ times**
- Should use semantic `AppTheme` constants

**Common Patterns:**
| Pattern | Occurrences | Purpose | Recommended |
|---------|-------------|---------|-------------|
| `Colors.white` | 46+ | Primary text | `AppTheme.textPrimary` (already defined) |
| `Colors.white70` | 112+ | Secondary text | `AppTheme.textSecondary` |
| `Colors.white60` | 35+ | Tertiary text | `AppTheme.textSubtle` (already defined) |
| `Colors.white.withValues(alpha: 0.X)` | Many | Various | Define opacity constants |

---

### 1.2 Summary Metrics

**Before Refactoring (January 2026):**
- ❌ **Total Color Definitions:** 50+ in AppTheme
- ❌ **Hardcoded Colors:** 22+ instances across 14 files
- ❌ **Green Variants:** 5 different shades
- ❌ **Red Variants:** 3 different shades
- ❌ **Background Variants:** 7 different shades
- ❌ **Files Needing Refactor:** 14+ priority files

**Current Status (After Phase 1):**
- ✅ **Total Color Definitions:** ~48 in AppTheme (removed green2)
- ✅ **Hardcoded Colors:** 0 outside app_theme.dart
- ✅ **Green Variants:** 1 (unified to #8CC63F)
- ⚠️ **Red Variants:** 3 (needs consolidation in Phase 2)
- ⚠️ **Background Variants:** 7 (needs consolidation in Phase 4)
- ⚠️ **Files Needing Refactor:** 0 for green/hardcoded, pending for phases 2-4

**Final Target (After Phase 4):**
- ✅ **Total Color Definitions:** ~35 (remove redundant)
- ✅ **Hardcoded Colors:** 0 (except in app_theme.dart)
- ✅ **Green Variants:** 1 (standard brand green)
- ✅ **Red Variants:** 2 (error + sell)
- ✅ **Background Variants:** 4 (clear hierarchy)
- ✅ **Files Needing Refactor:** 0

---

## 2. Implementation Roadmap

### Overview

The refactoring is divided into **4 phases**, prioritized by impact and risk:

```
✅ Phase 1: Green Unification + Hardcoded Cleanup (COMPLETE)
⚠️ Phase 2: Red & Purple Consolidation (TO IMPLEMENT)
⚠️ Phase 3: Text Color Standardization (TO IMPLEMENT)
⚠️ Phase 4: Background Hierarchy (TO IMPLEMENT - HIGH RISK)
```

---

### ✅ Phase 1: Green Unification + Hardcoded Cleanup

**Status:** ✅ **COMPLETE**
**Completed:** January 14, 2026
**PR:** `fix-colors` branch
**Risk Level:** 🟢 Low

#### Scope

**Primary Goal:** Unify all green color variants to single brand color

**Secondary Goal:** Replace hardcoded colors with AppTheme constants

#### Work Completed

**1. Green Unification:**
- ✅ Selected `#8CC63F` as official brand green
- ✅ Updated `mostroGreen` in app_theme.dart from `#9CD651` → `#8CC63F`
- ✅ Replaced all hardcoded `#8CC63F` instances with `AppTheme.mostroGreen`
- ✅ Updated payment_confirmation `#8CC541` → `AppTheme.mostroGreen`
- ✅ Removed unused `green2` legacy color from app_theme.dart
- ✅ Verified `buyColor` references `mostroGreen` (already aliased)

**2. Hardcoded Color Cleanup:**
- ✅ Replaced `Color(0xFF1D212C)` → `AppTheme.dark1` (5 files)
- ✅ Replaced `Color(0xFF1E2230)` → `AppTheme.backgroundCard` (5 files)
- ✅ Replaced `Color(0xFF303544)` → `AppTheme.dark2` (2 files)
- ✅ Replaced `Color(0xFF171A23)` → `AppTheme.backgroundDark` (2 files)
- ✅ Replaced `Color(0xFF252a3a)` → `AppTheme.backgroundInput` (2 files)
- ✅ Replaced `Color(0xFFF3CA29)` → `AppTheme.yellow` (2 files)
- ✅ Replaced `Color(0xFF764BA2)` → `AppTheme.purpleAccent` (1 file)
- ✅ Replaced `Color(0xFF1565C0)` → `AppTheme.createdByYouChip` (1 file)
- ✅ Replaced `Color(0xFF9aa1b6)` → `Colors.white70` (2 files)
- ✅ Replaced `Color(0xFF1A1A1A)` → `Colors.black` (1 file)

#### Files Changed (15 total)

**Green Unification:**
1. ✅ `lib/core/app_theme.dart` - Updated mostroGreen value, removed green2
2. ✅ `lib/features/order/widgets/amount_section.dart` - Hardcoded green → mostroGreen
3. ✅ `lib/features/order/widgets/payment_methods_section.dart` - Hardcoded green → mostroGreen
4. ✅ `lib/features/order/widgets/currency_section.dart` - Hardcoded green → mostroGreen
5. ✅ `lib/features/order/screens/add_order_screen.dart` - Multiple hardcoded colors
6. ✅ `lib/features/order/screens/payment_confirmation_screen.dart` - Payment green variant
7. ✅ `lib/features/order/widgets/order_type_header.dart` - Added import, used backgroundCard
8. ✅ `lib/shared/widgets/currency_selection_dialog.dart` - Hardcoded green → mostroGreen

**Hardcoded Color Cleanup:**
9. ✅ `lib/features/auth/screens/register_screen.dart` - dark1
10. ✅ `lib/features/auth/screens/login_screen.dart` - dark1
11. ✅ `lib/features/home/screens/home_screen.dart` - dark1 (2 instances)
12. ✅ `lib/shared/widgets/exchange_rate_widget.dart` - dark2
13. ✅ `lib/features/settings/about_screen.dart` - backgroundCard
14. ✅ `lib/features/disputes/widgets/dispute_message_bubble.dart` - createdByYouChip
15. ✅ `lib/features/walkthrough/screens/walkthrough_screen.dart` - text color
16. ✅ `lib/features/chat/widgets/info_buttons.dart` - Colors.black


#### Testing

- ✅ `flutter analyze` - Zero issues
- ✅ Visual testing on affected screens
- ✅ No behavioral changes, only color values

#### Metrics

- **Files Modified:** 16
- **Lines Changed:** ~25 color replacements
- **Colors Unified:** 5 greens → 1 green
- **Hardcoded Colors Removed:** 22+ instances
- **New Issues:** 0

---

### ⚠️ Phase 2: Red & Purple Consolidation

**Status:** ⚠️ **TO IMPLEMENT**
**Estimated Effort:** Small (~8-12 files)
**Risk Level:** 🟡 Medium
**Priority:** High

#### Scope

**Goals:**
1. Consolidate 3 red variants → 2 red variants (or justify keeping 3)
2. Clarify purple usage or consolidate to 1 purple
3. Document clear usage guidelines for each color

#### Work Required

**Red Colors - Decision Needed:**

Current state:
```dart
static const Color red1 = Color(0xFFD84D4D);        // Darkest - legacy?
static const Color red2 = Color(0xFFEF6A6A);        // Medium - statusError
static const Color sellColor = Color(0xFFFF8A8A);   // Lightest - sell actions
```

**Option A:** Keep 2 reds (error + sell)
```dart
// Remove red1 if unused
static const Color statusError = Color(0xFFEF6A6A);  // Error states
static const Color sellColor = Color(0xFFFF8A8A);    // Sell actions
```

**Option B:** Keep 2 reds with different semantic
```dart
static const Color statusError = Color(0xFFD84D4D);  // Darker for errors (more serious)
static const Color sellColor = Color(0xFFFF8A8A);    // Lighter for sell (less aggressive)
// Remove red2
```

**Purple Colors - Decision Needed:**

Current state:
```dart
static const Color purpleAccent = Color(0xFF764BA2);  // Accent elements
static const Color purpleButton = Color(0xFF7856AF);  // Submit buttons
```

**Option A:** Keep both with clear guidelines
- Document when to use purpleAccent vs purpleButton
- Ensure semantic naming is clear

**Option B:** Consolidate to 1 purple
- Choose which purple to keep
- Replace all usages of the other

#### Tasks Checklist

**Planning:**
- [ ] Audit all `red1`, `red2`, `sellColor` usages
- [ ] Audit all `purpleAccent`, `purpleButton` usages
- [ ] Decide on final red color strategy (Option A or B)
- [ ] Decide on final purple color strategy (Option A or B)
- [ ] Document rationale for decisions

**Implementation:**
- [ ] Update app_theme.dart with final colors
- [ ] Find and replace all red color usages
- [ ] Find and replace all purple color usages
- [ ] Remove unused color constants
- [ ] Add usage comments to remaining colors

**Testing:**
- [ ] Run `flutter analyze` (must be zero issues)
- [ ] Visual testing on all affected screens
- [ ] Screenshot comparison (before/after)

**Documentation:**
- [ ] Update this document with decisions
- [ ] Add to Decision Log section
- [ ] Create PR with clear description

**Purple-related files:**
- `lib/features/order/widgets/currency_section.dart` (purpleAccent)
- `lib/features/order/widgets/action_buttons.dart` (purpleButton)
- Possibly 2-3 other files

#### Success Criteria

- ✅ Clear semantic meaning for each red variant kept
- ✅ Purple usage guidelines documented (if keeping both)
- ✅ No unused color constants
- ✅ All usages centralized to AppTheme
- ✅ Zero flutter analyze issues
- ✅ No visual regressions

---

### ⚠️ Phase 3: Text Color Standardization

**Status:** ⚠️ **TO IMPLEMENT**
**Estimated Effort:** Large (~150+ replacements across 30-40 files)
**Risk Level:** 🟡 Medium
**Priority:** Medium (before high-risk background changes)

#### Scope

**Goal:** Replace all `Colors.whiteXX` with semantic `AppTheme` constants

**Current Problem:**
- `Colors.white70` used 112+ times
- `Colors.white60` used 35+ times
- Various `Colors.white.withValues(alpha: X)` scattered
- Should use semantic AppTheme constants

#### Proposed Replacements

**Define clear text hierarchy:**
```dart
// In app_theme.dart
static const Color textPrimary = Colors.white;           // 100% - Already exists
static const Color textSecondary = Color(0xFFCCCCCC);    // ~80% - Already exists
static const Color textTertiary = Colors.white60;        // 60% - Already exists as textSubtle
static const Color textDisabled = Color(0xFF8A8D98);     // Already exists as textInactive
```

**Replacements:**
```dart
// Before
color: Colors.white70

// After
color: AppTheme.textSecondary

---

// Before
color: Colors.white60

// After
color: AppTheme.textTertiary  // or AppTheme.textSubtle (already defined)

---

// Before
color: Colors.white.withValues(alpha: 0.4)

// After
color: AppTheme.textDisabled
```

#### Tasks Checklist

**Planning:**
- [ ] Decide on final text color naming
  - Keep `textSubtle` or rename to `textTertiary`?
  - Add new constants if needed
- [ ] Grep for all `Colors.white` pattern usages
- [ ] Create mapping: Pattern → AppTheme constant
- [ ] Estimate true scope (might be larger than 150)

**Implementation:**
- [ ] Update app_theme.dart with any new constants
- [ ] Add clear usage comments to text colors
- [ ] Replace Colors.white70 → AppTheme.textSecondary
- [ ] Replace Colors.white60 → AppTheme.textTertiary/textSubtle
- [ ] Replace dynamic alpha variations → defined constants
- [ ] Consider splitting into 2-3 sub-PRs if > 50 files

**Possible Sub-PRs:**
- Sub-PR 3.1: Feature screens (order, chat, settings)
- Sub-PR 3.2: Shared widgets and components
- Sub-PR 3.3: Auth and home screens

**Testing:**
- [ ] Run flutter analyze (must be zero issues)
- [ ] Visual verification (text should look identical)
- [ ] Check no unintended contrast changes

**Documentation:**
- [ ] Update this document
- [ ] Add Decision Log entry
- [ ] Update PR description with scope

#### Estimated Files to Change

- **30-40 files** minimum
- **150+ individual replacements**
- High-volume but low-risk changes

#### Success Criteria

- ✅ Zero `Colors.white70` usages outside app_theme.dart
- ✅ Zero `Colors.white60` usages outside app_theme.dart
- ✅ All text colors use semantic AppTheme constants
- ✅ Clear naming convention documented
- ✅ Zero flutter analyze issues
- ✅ No visual changes (colors should match exactly)

#### Notes

- **Low Risk:** Text colors are less visible than backgrounds
- **High Volume:** Consider automation/scripting for replacements
- **Can be iterative:** Safe to do in multiple smaller PRs
- **Good for final polish:** After phases 1-2 complete, before high-risk Phase 4

---
### ⚠️ Phase 4: Background Hierarchy Consolidation

**Status:** ⚠️ **TO IMPLEMENT**
**Estimated Effort:** Medium (~15-20 files)
**Risk Level:** 🔴 **HIGH** (affects visual hierarchy)
**Priority:** Final phase (proceed carefully due to high risk)

#### Scope

**Goal:** Reduce 7 background variants → 4 clear hierarchy levels

**Why High Risk:**
- Changes affect entire app's visual hierarchy
- Subtle background changes can impact perceived depth
- Many screens affected simultaneously
- Requires extensive visual testing

#### Proposed Final Hierarchy

**From 7 backgrounds:**
```dart
backgroundDark      #171A23  (Level 0)
backgroundNavBar    #1A1F2C  (Level 1) ← REMOVE
dark1               #1D212C  (Level 2) ← REMOVE
backgroundCard      #1E2230  (Level 3)
backgroundInput     #252A3A  (Level 4)
backgroundInactive  #2A3042  (Level 5) ← REMOVE
dark2               #303544  (Level 6)
```

**To 4 backgrounds:**
```dart
backgroundDark      #171A23  - Level 0: Main screen background (darkest)
backgroundCard      #1E2230  - Level 1: Cards, list items, elevated surfaces
backgroundInput     #252A3A  - Level 2: Input fields, interactive elements
backgroundElevated  #303544  - Level 3: Modals, dialogs, highest elevation (lightest)
```

#### Migration Strategy

**Step 1: Map Old → New**
```
backgroundNavBar    → backgroundDark or backgroundCard (decide based on usage)
dark1               → backgroundCard (visually very close)
backgroundInactive  → backgroundInput (semantic match)
dark2               → backgroundElevated (rename for clarity)
```

**Step 2: Create Migration Plan**
- [ ] Audit all 7 background color usages
- [ ] Create detailed mapping for each file
- [ ] Identify edge cases or special usages
- [ ] Plan rollback strategy if issues found

**Step 3: Implement in Stages** (Optional)
Consider splitting into 2 sub-PRs if risk too high:
- Sub-PR 4.1: Remove backgroundNavBar and dark1
- Sub-PR 4.2: Remove backgroundInactive, rename dark2

#### Tasks Checklist

**Planning Phase:**
- [ ] Grep for all background color usages
- [ ] Create spreadsheet mapping: File → Old Color → New Color
- [ ] Screenshot EVERY major screen (before state)
- [ ] Identify high-traffic screens for priority testing
- [ ] Document expected visual changes

**Implementation Phase:**
- [ ] Update app_theme.dart
  - [ ] Remove: backgroundNavBar, backgroundInactive
  - [ ] Rename: dark1 → (consolidate with backgroundCard)
  - [ ] Rename: dark2 → backgroundElevated
  - [ ] Add clear usage comments
- [ ] Replace all usages file by file
- [ ] Run flutter analyze after each batch

**Testing Phase (CRITICAL):**
- [ ] Test on multiple screen sizes
- [ ] Test on different device densities
- [ ] Verify visual hierarchy feels correct
- [ ] Check no "lost" elements (same bg as parent)
- [ ] User acceptance testing (optional but recommended)

**Documentation Phase:**
- [ ] Update this document
- [ ] Add detailed Decision Log entry
- [ ] Document visual changes in PR description
- [ ] Include before/after screenshots in PR

#### Estimated Files to Change

**High probability (known usages):**
- Most scaffold backgrounds
- Card containers
- Dialog backgrounds
- Navigation components
- Input field containers
- ~15-20 files estimated

#### Success Criteria

- ✅ Only 4 background colors remain
- ✅ Clear semantic hierarchy
- ✅ Visual hierarchy preserved or improved
- ✅ No "lost" UI elements
- ✅ Zero flutter analyze issues
- ✅ Before/after screenshots documented
- ✅ Team approval on visual changes

#### Risk Mitigation

**If Issues Found:**
- Have rollback plan ready
- Consider feature flag for gradual rollout
- Revert immediately if critical visual regression
- Split into smaller PRs if too risky

---

## 3. Decision Log

This section documents all major decisions made during the refactoring, including rationale and alternatives considered.

### Phase 1 Decisions

#### Decision 1.1: Official Brand Green

**Decision:** Use `#8CC63F` as the single official brand green

**Date:** January 14, 2026

`#8CC63F` **SELECTED**
   - ✅ Most widely used variant (~10 files)
   - ✅ Already implemented in majority of UI
   - ✅ Developers intuitively chose this shade
   - ✅ Better contrast on dark backgrounds

**Rationale:**
The hardcoded `#8CC63F` was used in 10+ files, indicating this was the "de facto" standard developers naturally gravitated toward. Additionally, the selected color is the closest match to the color currently used in the Mostro logo, compared to all other color options used in the app.

**Visual Difference:**
- Old: `#9CD651` - Slightly lighter, more lime
- New: `#8CC63F` - Slightly darker, richer green

**Impact:**
- All green variants now unified to this single value
- Minimal visual change (most UI already used this)
- `buyColor` and `statusSuccess` now reference this value

---

#### Decision 1.2: Remove green2 Legacy Color

**Decision:** Delete unused `green2` color constant

**Date:** January 14, 2026

**Rationale:**
- Zero usages found in entire codebase
- Only existed in app_theme.dart definition
- Legacy artifact from previous design
- Keeping unused colors creates confusion

**Impact:** None (no code referenced it)

---

#### Decision 1.3: Centralize All Hardcoded Colors

**Decision:** Replace all hardcoded color values with AppTheme constants

**Date:** January 14, 2026

**Alternatives Considered:**
1. **Option A:** Leave some hardcoded if "unique"
   - ❌ Inconsistent approach
   - ❌ Creates exceptions to rule

2. **Option B:** Centralize everything ⭐ **SELECTED**
   - ✅ Single source of truth
   - ✅ Easier maintenance
   - ✅ Clear rule: NO hardcoded colors

**Rationale:**
Having a single rule ("all colors in app_theme.dart") is clearer than "most colors in app_theme.dart except for special cases". Even one-off colors benefit from centralization for future refactoring.

**Impact:**
- 22+ hardcoded instances removed
- All colors now maintainable from single file
- Clear pattern for future development

---

#### Decision 1.4: Replace #9aa1b6 with Colors.white70

**Decision:** Use Flutter's built-in `Colors.white70` instead of custom gray

**Date:** January 14, 2026

**Alternatives Considered:**
1. **Option A:** Create `AppTheme.textWalkthrough` constant
   - ❌ Adds color for 2 usages only
   - ❌ Walkthrough-specific, not semantic

2. **Option B:** Use existing `Colors.white70` ⭐ **SELECTED**
   - ✅ Standard Flutter constant
   - ✅ Visually very similar
   - ✅ Reduces custom color count

**Rationale:**
The custom gray `#9aa1b6` was only used in walkthrough screen text. `Colors.white70` is visually nearly identical and is a standard Flutter constant. No need to add a custom color for this edge case.

---

#### Decision 1.5: Replace #1A1A1A with Colors.black

**Decision:** Use Flutter's `Colors.black` instead of custom near-black

**Date:** January 14, 2026

**Rationale:**
- Only used once (info button text on green background)
- `#1A1A1A` is 99% identical to pure black
- No visual benefit to custom near-black
- Reduces color palette complexity

**Impact:** None visible (colors virtually identical)

---

### Phase 2 Decisions

*To be documented during Phase 2 implementation*

---

### Phase 3 Decisions

*To be documented during Phase 3 implementation*

---

### Phase 4 Decisions

*To be documented during Phase 4 implementation*

---

## 4. Final Color Palette

This section will document the final, approved color palette after all phases complete. Currently reflects Phase 1 completion.

### 4.1 Brand Colors

| Color Name | Hex | RGB | Usage | Status |
|------------|-----|-----|-------|--------|
| **Primary Green** | `#8CC63F` | (140, 198, 63) | Main brand color, buttons, active states | ✅ Finalized |

**Usage Guidelines:**
- ✅ DO: Use for all primary brand elements
- ✅ DO: Use for success states
- ✅ DO: Use for active/selected states
- ❌ DON'T: Create green variants without team approval

---

### 4.2 Action Colors

| Color Name | Hex | RGB | Usage | Status |
|------------|-----|-----|-------|--------|
| **Buy Green** | `#8CC63F` | (140, 198, 63) | Buy action buttons | ✅ Finalized |
| **Sell Red** | `#FF8A8A` | (255, 138, 138) | Sell action buttons | ⚠️ To review in Phase 2 |

**Current State:**
- Buy color finalized and unified with brand green
- Sell color needs review (is this the right red?)

---

### 4.3 Status Colors

| Color Name | Hex | RGB | Usage | Status |
|------------|-----|-----|-------|--------|
| **Success** | `#8CC63F` | (140, 198, 63) | Success messages, completed states | ✅ Finalized |
| **Warning** | `#F3CA29` | (243, 202, 41) | Warnings, pending states | ✅ Finalized |
| **Error** | `#EF6A6A` | (239, 106, 106) | Error messages, failed states | ⚠️ To review in Phase 2 |
| **Info** | `#2A7BD6` | (42, 123, 214) | Informational messages | ✅ Finalized |

---

### 4.4 Background Hierarchy

**Current State (Phase 1):** 7 backgrounds - needs consolidation in Phase 4

| Level | Color Name | Hex | RGB | Usage | Status |
|-------|------------|-----|-----|-------|--------|
| 0 | backgroundDark | `#171A23` | (23, 26, 35) | Main screen background | ✅ Keep |
| 1 | backgroundNavBar | `#1A1F2C` | (26, 31, 44) | Navigation bar | ⚠️ Remove in Phase 4 |
| 2 | dark1 | `#1D212C` | (29, 33, 44) | Alternative background | ⚠️ Remove in Phase 4 |
| 3 | backgroundCard | `#1E2230` | (30, 34, 48) | Cards, elevated surfaces | ✅ Keep |
| 4 | backgroundInput | `#252A3A` | (37, 42, 58) | Input fields | ✅ Keep |
| 5 | backgroundInactive | `#2A3042` | (42, 48, 66) | Inactive elements | ⚠️ Remove in Phase 4 |
| 6 | dark2 | `#303544` | (48, 53, 68) | Dialogs, modals | ✅ Keep (rename) |

**Proposed Final (Phase 4):** 4 backgrounds

| Level | Color Name | Hex | Usage |
|-------|------------|-----|-------|
| 0 | backgroundDark | `#171A23` | Main screen background (darkest) |
| 1 | backgroundCard | `#1E2230` | Cards, list items, elevated surfaces |
| 2 | backgroundInput | `#252A3A` | Input fields, interactive elements |
| 3 | backgroundElevated | `#303544` | Modals, dialogs, highest elevation (lightest) |

---

### 4.5 Text Colors

**Current State:** Partially centralized, Phase 3 will complete

| Color Name | Value | Usage | Status |
|------------|-------|-------|--------|
| textPrimary | `Colors.white` | Primary content text | ✅ Defined |
| textSecondary | `#CCCCCC` | Supporting text, labels | ✅ Defined |
| textInactive | `#8A8D98` | Disabled text | ✅ Defined |
| textSubtle | `Colors.white60` | Subtle text, timestamps | ✅ Defined |
| secondaryText | `#BDBDBD` | Alternative secondary (redundant?) | ⚠️ Review in Phase 3 |

**Pending Phase 3:**
- Evaluate if `textSubtle` and `secondaryText` overlap
- Replace all `Colors.white70` → `AppTheme.textSecondary`
- Replace all `Colors.white60` → `AppTheme.textSubtle`
- Define any missing text color constants

---

### 4.6 Accent Colors

| Color Name | Hex | RGB | Usage | Status |
|------------|-----|-----|-------|--------|
| **Purple Accent** | `#764BA2` | (118, 75, 162) | Accent elements | ⚠️ Review in Phase 2 |
| **Purple Button** | `#7856AF` | (120, 86, 175) | Submit buttons | ⚠️ Review in Phase 2 |

**Pending Phase 2:**
- Decide if both purples are needed
- Document clear usage guidelines if keeping both
- Consider consolidation to single purple

---

### 4.7 Status Chip Colors

**Status:** ✅ Well-organized, no changes needed

These color pairs are well-designed and should remain as-is:

| Status | Background | Text |
|--------|------------|------|
| Pending | `#854D0E` | `#FCD34D` |
| Waiting | `#7C2D12` | `#FED7AA` |
| Active | `#1E3A8A` | `#93C5FD` |
| Success | `#065F46` | `#6EE7B7` |
| Dispute | `#7F1D1D` | `#FCA5A5` |
| Settled | `#581C87` | `#C084FC` |
| Inactive | `#1F2937` | `#D1D5DB` |

**Note:** This is the best-organized color system in the app. Keep as reference for future patterns.

---

### 4.8 Role Chip Colors

**Status:** ✅ Well-defined, no changes needed

| Role | Hex | RGB | Usage |
|------|-----|-----|-------|
| Created by You | `#1565C0` | (21, 101, 192) | Orders you created |
| Taken by You | `#00796B` | (0, 121, 107) | Orders you took |
| Premium Positive | `#388E3C` | (56, 142, 60) | Positive premium |
| Premium Negative | `#C62828` | (198, 40, 40) | Negative premium |

---

## 5. Migration Guidelines

This section provides rules and patterns for maintaining color consistency going forward.

### 5.1 Core Rules

#### Rule 1: Single Source of Truth ✅
**ALL colors must be defined in `lib/core/app_theme.dart`**

```dart
// ❌ BAD - Hardcoded color
Container(
  color: Color(0xFF8CC63F),
)

// ✅ GOOD - AppTheme constant
Container(
  color: AppTheme.mostroGreen,
)
```

---

#### Rule 2: Semantic Naming ✅
**Use semantic names that describe purpose, not appearance**

```dart
// ❌ BAD - Describes appearance
static const Color lightGreen = Color(0xFF8CC63F);
static const Color darkGray = Color(0xFF1D212C);

// ✅ GOOD - Describes purpose
static const Color mostroGreen = Color(0xFF8CC63F);   // Brand color
static const Color backgroundDark = Color(0xFF1D212C); // Darkest background
```

---

#### Rule 3: No Color Duplication ✅
**Use aliases instead of duplicating color values**

```dart
// ❌ BAD - Duplicate values
static const Color mostroGreen = Color(0xFF8CC63F);
static const Color buyColor = Color(0xFF8CC63F);      // Duplicate!

// ✅ GOOD - Alias to single source
static const Color mostroGreen = Color(0xFF8CC63F);
static const Color buyColor = mostroGreen;            // Alias
```

---

#### Rule 4: Document Usage ✅
**Add comments explaining when to use each color**

```dart
// ✅ GOOD - Clear documentation
/// Main brand color - use for primary actions, active states, success indicators
static const Color mostroGreen = Color(0xFF8CC63F);

/// Sell action color - use ONLY for sell-related actions
static const Color sellColor = Color(0xFFFF8A8A);
```

---

### 5.2 Adding New Colors

**Process for adding a new color:**

1. **Question:** Can I use an existing color?
   - Check app_theme.dart first
   - Consider if existing color fits semantically

2. **If new color needed:**
   ```dart
   // Add to appropriate section in app_theme.dart

   // Action Colors section
   static const Color newActionColor = Color(0xFFXXXXXX);

   // OR

   // Status Colors section
   static const Color statusNewState = Color(0xFFXXXXXX);
   ```

3. **Add usage comment:**
   ```dart
   /// Brief description of when to use this color
   static const Color newColor = Color(0xFFXXXXXX);
   ```

4. **Update DESIGN_SYSTEM.md:**
   - Add to Section 4 (Final Color Palette)
   - Document the decision in Section 3 (Decision Log)

5. **Get team approval** before merging

---

### 5.3 Common Patterns

#### Pattern 1: Backgrounds

```dart
// ✅ Correct hierarchy
Scaffold(
  backgroundColor: AppTheme.backgroundDark,  // Level 0
  body: Card(
    color: AppTheme.backgroundCard,          // Level 1
    child: TextField(
      decoration: InputDecoration(
        fillColor: AppTheme.backgroundInput,  // Level 2
      ),
    ),
  ),
)
```

---

#### Pattern 2: Text Colors

```dart
// ✅ Clear hierarchy
Text(
  'Heading',
  style: TextStyle(color: AppTheme.textPrimary),  // Most important
)

Text(
  'Description',
  style: TextStyle(color: AppTheme.textSecondary),  // Supporting
)

Text(
  '2 hours ago',
  style: TextStyle(color: AppTheme.textSubtle),     // Subtle
)
```

---

#### Pattern 3: Status Colors

```dart
// ✅ Use semantic status colors
Icon(
  Icons.check,
  color: AppTheme.statusSuccess,  // Success = green
)

Icon(
  Icons.warning,
  color: AppTheme.statusWarning,  // Warning = yellow
)

Icon(
  Icons.error,
  color: AppTheme.statusError,    // Error = red
)
```

---

### 5.4 Migration Scripts (Optional)

For large-scale replacements, consider using find-replace scripts:

```bash
# Find all hardcoded colors
grep -r "Color(0x" lib/ --exclude-dir=generated

# Find specific color value
grep -r "0xFF8CC63F" lib/

# Find Colors.white70 usage
grep -r "Colors.white70" lib/
```
---

## 6. Next Steps

  After Phase 4 completion:
  1. ✅ Mark this document as COMPLETE
  2. ✅ Create BRAND_GUIDELINES.md with finalized rules
  3. ✅ Update CLAUDE.md to reference BRAND_GUIDELINES.md
  4. ✅ Announce to team: Use BRAND_GUIDELINES.md for day-to-day work
  5. ✅ Keep this document for historical reference



## Changelog

| Date | Version | Changes | Author |
|------|---------|---------|--------|
| 2026-01-14 | 1.0.0 | Initial document creation, Phase 1 complete | 

---

**Document Status:** 🚧 Active (In Progress)
**Next Review:** After Phase 2 completion
