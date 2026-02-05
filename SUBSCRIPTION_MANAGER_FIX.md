# SubscriptionManager Bug Fix - Stuck Orders Resolution

## Problem Description

Orders were getting stuck in previous states (e.g., `waiting-buyer-invoice` when they should show `waiting-payment`) when the app was restarted. This happened because:

1. **Root Cause**: `fireImmediately: false` in SubscriptionManager prevented automatic subscription creation for existing sessions
2. **Symptom**: No Kind 1059 event subscriptions were created for sessions that existed before SubscriptionManager initialization
3. **Impact**: Users saw stale order states until creating a new order (which triggered subscription creation)

## Solution Implemented

**Opción B: Manual Initialization Pattern**

### Changes Made

#### File: `lib/features/subscriptions/subscription_manager.dart`

1. **Added explicit initialization call in constructor:**
```dart
SubscriptionManager(this.ref) {
  _initSessionListener();
  _initializeExistingSessions(); // NEW: Explicit initialization
}
```

2. **Added new method `_initializeExistingSessions()`:**
```dart
/// CRITICAL: Initialize subscriptions for existing sessions
/// DO NOT REMOVE: Fixes stuck orders bug when app restarts with existing sessions
/// 
/// This method ensures that subscriptions are created for sessions that already 
/// exist when SubscriptionManager is created, since fireImmediately: false 
/// prevents automatic initialization.
void _initializeExistingSessions() {
  try {
    final existingSessions = ref.read(sessionNotifierProvider);
    if (existingSessions.isNotEmpty) {
      _logger.i('Initializing subscriptions for ${existingSessions.length} existing sessions');
      _updateAllSubscriptions(existingSessions);
    } else {
      _logger.i('No existing sessions found during SubscriptionManager initialization');
    }
  } catch (e, stackTrace) {
    _logger.e('Error initializing existing sessions',
        error: e, stackTrace: stackTrace);
  }
}
```

## Why This Solution

### ✅ **Pros:**
- **Preserves `fireImmediately: false`**: Maintains the fix for relay switching bug (commit 63dc124e)
- **Explicit Control**: Clear, predictable timing of subscription creation
- **Framework Independent**: Doesn't depend on Flutter UI lifecycle
- **Easy Testing**: Can be unit tested without UI dependencies
- **Clear Documentation**: Well-documented purpose and critical nature

### ❌ **Cons:**
- **Manual Management**: Requires discipline to not remove the initialization call
- **Code Duplication**: `_updateAllSubscriptions()` called in two places

### **Mitigation:**
- Added comprehensive comments explaining the critical nature
- Used clear method naming to indicate importance
- Added error handling with logging

## Expected Behavior After Fix

1. **App Restart with Existing Sessions:**
   - ✅ SubscriptionManager creates subscriptions immediately for existing sessions
   - ✅ Kind 1059 events are received and processed correctly
   - ✅ Orders show current state (e.g., `waiting-payment`) instead of stale state

2. **Session State Changes:**
   - ✅ New sessions trigger subscription creation via the listener
   - ✅ Session deletions trigger subscription cleanup via the listener
   - ✅ Both initialization paths work independently

3. **Relay Switching:**
   - ✅ `fireImmediately: false` still prevents the original race condition
   - ✅ No regression of the relay switching bug

## Testing Verification

- ✅ **Compilation**: `dart analyze` shows no issues
- ✅ **Code Generation**: `dart run build_runner build -d` successful
- ✅ **Architecture**: Maintains existing patterns and doesn't break encapsulation

## Implementation Status

- ✅ **Implemented**: Manual initialization pattern (Option B)
- ✅ **Verified**: Code compiles and analyzes cleanly
- ✅ **Documented**: Clear comments explaining purpose and criticality
- ✅ **Error Handling**: Comprehensive error handling with logging

## Notes for Future Maintenance

1. **NEVER REMOVE** the `_initializeExistingSessions()` call from the constructor
2. **IF MODIFYING** the constructor, ensure both `_initSessionListener()` and `_initializeExistingSessions()` are called
3. **WHEN DEBUGGING** subscription issues, check logs for "Initializing subscriptions for X existing sessions"
4. **IF TESTING** requires modifications, preserve the initialization pattern

---

**Fix Date**: 2025-01-18  
**Issue**: Stuck orders after app restart  
**Solution**: Manual subscription initialization for existing sessions  
**Status**: Implemented and verified