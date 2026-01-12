# FCM Implementation for MostroP2P Mobile

## MIP-05 Implementation Overview

This implementation follows the **MIP-05 (Marmot Push Notifications)** specification for privacy-preserving push notifications. Below is an overview of which aspects are being implemented and why.

### ✅ Implemented Aspects

#### 1. Silent Push Notifications
**What:** FCM sends empty notifications with no message content
**Why:** Prevents Firebase/Google from learning message content, sender identity, or group membership
**Implementation:** 
- FCM notifications contain only `content-available` flag
- App fetches and decrypts actual messages from Nostr relays when awakened

#### 2. Encrypted Token Registration
**What:** Device tokens are encrypted using ChaCha20-Poly1305 with ECDH key derivation
**Why:** Prevents the notification server from linking tokens to user identities or correlating across groups
**Implementation:**
- Generate ephemeral secp256k1 keypair per token
- Derive encryption key via ECDH + HKDF (salt: "mostro-fcm-v1", info: "mostro-token-encryption")
- Encrypt with random 12-byte nonce for probabilistic encryption
- Token format: `ephemeral_pubkey || nonce || ciphertext` (280 bytes total)

#### 3. Payload Padding
**What:** All encrypted tokens padded to uniform 220 bytes before encryption
**Why:** Prevents group members from inferring platforms (APNs vs FCM) from token sizes
**Implementation:**
- Format: `platform_byte (1) || token_length (2) || device_token || random_padding`
- Platform bytes: 0x01 = APNs, 0x02 = FCM
- Ensures uniform 280-byte encrypted tokens

#### 4. Custom Notification Server
**What:** Dedicated server (mostro-push-server) handles token registration and FCM delivery
**Why:** Provides persistent WebSocket connections to Nostr relays, avoiding Cloud Functions limitations
**Implementation:**
- Server monitors Nostr relays for new events
- Decrypts tokens and sends silent push notifications via FCM
- State-minimized design with no persistent token storage

### ⚠️ Partially Implemented / Simplified Aspects

#### 5. Token Distribution (Simplified)
**MIP-05 Approach:** Gossip-based protocol with kind 447/448/449 events in MLS groups
**MostroP2P Approach:** Direct registration with notification server
**Why Simplified:** MostroP2P uses a different architecture (not MLS-based groups)
**Implementation:**
- Device registers encrypted token directly with notification server
- Server maintains token list for each user
- No group-based token sharing required

#### 6. Gift-Wrapped Notification Triggers (Simplified)
**MIP-05 Approach:** NIP-59 gift-wrapped events to trigger notifications
**MostroP2P Approach:** Server monitors Nostr relays directly for relevant events
**Why Simplified:** MostroP2P has a simpler event model that doesn't require gift wrapping
**Implementation:**
- Server monitors relays for new trade events
- No need for encrypted event wrapping in MostroP2P context

### ❌ Not Implemented Aspects

#### 7. MLS Group Integration
**Reason:** MostroP2P doesn't use MLS (Message Layer Security) for group management
**Alternative:** MostroP2P uses direct user-to-user trades and simple group concepts

#### 8. Multi-Server Token Management
**Reason:** MostroP2P uses a single notification server (mostro-push-server)
**Alternative:** Simplified architecture with single server reduces complexity

#### 9. Tor Support
**Reason:** Not prioritized for initial implementation
**Future:** Could be added as an optional privacy enhancement

#### 10. Decoy Tokens
**Reason:** MostroP2P's trade model doesn't require group size obfuscation
**Alternative:** Privacy is maintained through other means (encrypted tokens, silent push)

### 🔒 Privacy Properties Maintained

#### What Firebase/Google Learn:
- ✅ A notification occurred for a device (unavoidable with push)
- ✅ Device owner's platform identity (Google account via FCM token)

#### What Firebase/Google CANNOT Learn:
- ✅ Message content (notifications are silent/empty)
- ✅ Sender's Nostr identity
- ✅ Recipient's Nostr identity
- ✅ Trade details or order information
- ✅ Group membership (not applicable to MostroP2P)

#### What Notification Server Learns:
- ✅ Timing of notification events
- ✅ Encrypted device tokens (cannot decrypt to actual FCM tokens)

#### What Notification Server CANNOT Learn:
- ✅ Message content
- ✅ Sender's Nostr identity
- ✅ Recipient's Nostr identity
- ✅ Which Nostr user owns which device token
- ✅ User IP addresses (relays observe IPs)

### 📋 Implementation Phases

The implementation is divided into phases to match MostroP2P's architecture while maintaining MIP-05 privacy principles:

- **Phase 1:** Firebase basic configuration ✅ COMPLETE
- **Phase 2:** FCM service with background integration ✅ COMPLETE
- **Phase 3:** Encrypted token registration with server ✅ COMPLETE
- **Phase 4:** User settings and opt-out controls ⚠️ TO IMPLEMENT

### 🎯 Key Differences from MIP-05

| Aspect | MIP-05 | MostroP2P Implementation |
|--------|--------|---------------------------|
| **Token Distribution** | Gossip protocol in MLS groups | Direct server registration |
| **Event Triggers** | Gift-wrapped NIP-59 events | Direct relay monitoring |
| **Group Model** | MLS-based encrypted groups | Simple user-to-user trades |
| **Multi-Server** | Support for multiple servers | Single dedicated server |
| **Decoys** | Required for privacy | Not needed for trade model |

Despite these differences, the core privacy properties of MIP-05 are maintained:
- Silent push notifications
- Encrypted token registration
- Minimal metadata exposure
- User opt-out capability

### Why a Custom Server?

The initial approach was to use **Firebase Cloud Functions** as the notification server. However, this proved to be **unstable and limiting** because:

- ❌ **No WebSocket support:** Cloud Functions cannot maintain persistent WebSocket connections with Nostr relays
- ❌ **Cold starts:** Functions experience significant latency on cold starts, delaying notifications
- ❌ **Unreliable for real-time:** Not suitable for monitoring relay events in real-time
- ❌ **Complexity:** Additional overhead for managing function deployments and monitoring

The custom server approach ([mostro-push-server](https://github.com/MostroP2P/mostro-push-server)) provides:

- ✅ **Persistent WebSocket connections** to Nostr relays for real-time event monitoring
- ✅ **Stable and reliable** notification delivery
- ✅ **Lower latency** - no cold starts
- ✅ **Full control** over server behavior and monitoring
- ✅ **Simpler architecture** - dedicated service for one purpose

## Privacy Properties

### What Firebase/Google Learn
- A notification occurred for a specific device
- The device owner's platform identity (Google account) via FCM token

### What Firebase/Google CANNOT Learn
- Message content (notifications are silent/empty)
- Sender's Nostr identity
- Recipient's Nostr identity
- Order details or trade information
- Any relationship between the device and specific Nostr accounts

### What the Notification Server Learns
- Timing of notification events
- Encrypted device tokens (cannot decrypt to actual FCM tokens)

### What the Notification Server CANNOT Learn
- Message content
- Sender's Nostr identity
- Recipient's Nostr identity
- Which Nostr user owns which device token
- User IP addresses (only relays observe IPs)

## Architecture

```
┌─────────────────┐
│  MostroP2P App  │
│   (Flutter)     │
└────────┬────────┘
         │
         │ 1. Register encrypted token
         │    (ChaCha20-Poly1305)
         ▼
┌─────────────────┐
│ Notification    │
│ Server          │◄──── 2. Nostr relay monitors
│ (Separate Repo) │      for new events
└────────┬────────┘
         │
         │ 3. Send silent push
         ▼
┌─────────────────┐
│ Firebase Cloud  │
│ Messaging (FCM) │
└────────┬────────┘
         │
         │ 4. Wake app (silent notification)
         ▼
┌─────────────────┐
│  MostroP2P App  │
│  (Background)   │──► 5. Existing background
└─────────────────┘     notification system
                        handles the rest
```

**Note:** The app already has a background notification system implemented. FCM is only used to **wake up the app** with silent push notifications. Once awake, the existing notification system takes over to fetch, decrypt, and display messages.

## Implementation Phases

The implementation is divided into multiple phases (Pull Requests) to facilitate easier code review and incremental testing.

---

## Phase 1: Firebase Basic Configuration ✅ COMPLETE

**Branch:** `feature/firebase-fcm-setup`

**Objective:** Set up Firebase project and basic dependencies without any notification logic.

### Changes
- Configure Firebase project `mostro-mobile` (ID: 375342057498)
- Add `firebase_core` and `firebase_messaging` dependencies
- Configure Android `build.gradle` for Firebase
- Generate `firebase_options.dart` for all platforms
- Include `google-services.json` in Git (public credentials - safe to commit)
- Document Linux compatibility (Firebase not supported on Linux)

### Files Added/Modified
- `.firebaserc` - Firebase project configuration
- `firebase.json` - FlutterFire CLI configuration
- `lib/firebase_options.dart` - Firebase options for all platforms
- `android/app/google-services.json` - Android Firebase configuration
- `android/app/build.gradle` - Firebase dependencies
- `android/settings.gradle` - Google Services plugin
- `pubspec.yaml` - Firebase dependencies
- `.gitignore` - Allow Firebase config files
- `docs/FIREBASE_LINUX_NOTE.md` - Linux compatibility notes

### Testing
- ✅ `flutter analyze` passes without errors
- ✅ App compiles on all supported platforms
- ✅ No Firebase initialization yet (just configuration)

---

## Phase 2: FCM Service Implementation ✅ COMPLETE

**Branch:** `feature/fcm-service`

**Objective:** Implement FCM token management and integrate with existing background notification system.

### Changes
- Create `FCMService` class for Firebase Cloud Messaging operations
- Implement FCM token generation and retrieval
- Handle FCM token refresh events
- Request notification permissions (Android/iOS)
- Implement background message handler to trigger existing notification system
- Integrate FCM initialization in app startup (with Platform.isLinux check)

### Files to Add/Modify
- `lib/services/fcm_service.dart` - Core FCM service with background handler
- `lib/main.dart` - Initialize Firebase and FCM on app startup
- `lib/core/providers.dart` - Riverpod provider for FCMService
- `lib/features/notifications/services/background_notification_service.dart` - Integration point
- `android/app/src/main/AndroidManifest.xml` - Background execution permissions (if needed)

### Background Handler Integration
```dart
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // 1. Initialize minimal Firebase
  await Firebase.initializeApp();
  
  // 2. Silent notification received (empty - no data in message)
  // 3. Trigger existing background notification system
  //    (app already has flutter_background_service implemented)
  // 4. Existing system handles:
  //    - Fetching new messages from Nostr relays
  //    - Decrypting messages locally
  //    - Displaying local notifications
  //    - Updating badge count
}
```

### Key Features
- **Token Management:** Generate, store, and refresh FCM tokens
- **Permission Handling:** Request notification permissions on first launch
- **Platform Detection:** Skip Firebase initialization on Linux
- **Token Persistence:** Store token locally using `shared_preferences`
- **Background Wake-up:** Silent push wakes app to trigger existing notification system
- **No Duplication:** Leverage existing `flutter_background_service` and `flutter_local_notifications`

### Testing
- Verify FCM token generation on Android
- Test permission request flow
- Verify token refresh on app restart
- Confirm Linux builds skip Firebase initialization
- Test background notification reception (app closed)
- Verify existing notification system is triggered correctly
- Confirm no duplicate notifications

---

## Phase 3: Push Notification Service with Encryption ✅ COMPLETE

**Branch:** `feature/push-notification-service`

**Objective:** Implement encrypted token registration with the custom notification server.

### Changes
- Create `PushNotificationService` for server communication
- Implement token encryption using ChaCha20-Poly1305
- Implement ECDH key derivation with server's public key
- Register encrypted tokens with notification server
- Handle token unregistration on logout/disable

### Files to Add/Modify
- `lib/services/push_notification_service.dart` - Encrypted token registration
- `lib/core/config.dart` - Add notification server public key and endpoints
- `lib/services/fcm_service.dart` - Integration with PushNotificationService

### Encryption Implementation
Following MIP-05 approach:

```dart
// 1. Generate ephemeral keypair for this token encryption
ephemeral_privkey = random_bytes(32)
ephemeral_pubkey = secp256k1.get_pubkey(ephemeral_privkey)

// 2. Derive encryption key using ECDH + HKDF
shared_x = secp256k1_ecdh(ephemeral_privkey, server_pubkey)
prk = HKDF-Extract(salt="mostro-fcm-v1", IKM=shared_x)
encryption_key = HKDF-Expand(prk, "mostro-token-encryption", 32)

// 3. Generate random nonce for probabilistic encryption
nonce = random_bytes(12)

// 4. Construct padded payload (uniform size)
padded_payload = platform_byte || token_length || device_token || random_padding

// 5. Encrypt with ChaCha20-Poly1305
ciphertext = ChaCha20-Poly1305.encrypt(
    key: encryption_key,
    nonce: nonce,
    plaintext: padded_payload,
    aad: ""
)

// 6. Token package
encrypted_token = ephemeral_pubkey || nonce || ciphertext
```

### Key Features
- **Probabilistic Encryption:** Same FCM token produces different ciphertexts each time
- **Server Cannot Decrypt:** Only the notification server (with private key) can decrypt
- **Payload Padding:** Uniform token size prevents platform fingerprinting
- **HTTPS Communication:** Secure token registration endpoint

### Testing
- Verify token encryption produces different ciphertexts
- Test successful registration with notification server
- Verify encrypted token format (ephemeral_pubkey || nonce || ciphertext)
- Test token unregistration flow

---

## Phase 4: User Settings and Opt-Out ⚠️ TO IMPLEMENT

**Branch:** `feature/notification-settings` (to be created from `main` after Phase 3 merge)

**Objective:** Provide user controls for notification preferences.

### Changes
- Add notification settings screen
- Implement enable/disable toggle for push notifications
- Add notification sound/vibration preferences
- Implement token unregistration on disable
- Add notification preview in settings

### Files to Add/Modify
- `lib/features/settings/screens/notification_settings_screen.dart` - Settings UI
- `lib/features/settings/providers/notification_settings_provider.dart` - Settings state
- `lib/services/push_notification_service.dart` - Handle enable/disable

### Key Features
- **Enable/Disable Toggle:** Complete opt-out from push notifications
- **Token Cleanup:** Unregister token from server when disabled
- **Preferences:** Sound, vibration, notification preview settings
- **Privacy Notice:** Explain what data is shared with Firebase/Google

### Testing
- Test enable/disable toggle
- Verify token unregistration on disable
- Test notification preferences (sound, vibration)
- Verify settings persistence across app restarts

---

## Implementation Notes

### Platform Support
- ✅ **Android:** Full FCM support
- ✅ **iOS:** Will require APNs configuration (future work)
- ❌ **Linux:** Firebase not supported, notifications disabled
- ⚠️ **Web/Windows/macOS:** Firebase supported but notifications may have limitations

### Security Considerations
- **No Message Content in Push:** FCM notifications are always silent/empty
- **Encrypted Tokens:** Device tokens encrypted before sending to server
- **Local Decryption:** All Nostr message decryption happens on device
- **Ephemeral Keys:** Each token encryption uses fresh ephemeral keypair
- **Server Cannot Correlate:** Probabilistic encryption prevents cross-user correlation

### Dependencies
- `firebase_core: ^3.8.0` - Firebase initialization
- `firebase_messaging: ^15.1.4` - FCM functionality (silent push only)
- `flutter_local_notifications: ^19.0.0` - Already implemented (existing system)
- `flutter_background_service: ^5.1.0` - Already implemented (existing system)
- `pointycastle: ^3.9.1` - ChaCha20-Poly1305 encryption
- `crypto: ^3.0.5` - HKDF key derivation

### Related Documentation
- `docs/FIREBASE_LINUX_NOTE.md` - Linux compatibility notes
- [MIP-05 specification](https://github.com/marmot-protocol/marmot/pull/18) - Privacy-preserving push notifications approach
- [mostro-push-server](https://github.com/MostroP2P/mostro-push-server) - Custom notification server repository
- [Firebase Cloud Messaging documentation](https://firebase.google.com/docs/cloud-messaging)
- [NIP-59 (Gift Wrap)](https://github.com/nostr-protocol/nips/blob/master/59.md) - Nostr event encryption standard

---

## Future Enhancements

### Potential Improvements (Not in Current Scope)
- **iOS APNs Integration:** Native iOS push notifications
- **Notification Grouping:** Group multiple order updates
- **Rich Notifications:** Add action buttons (Accept/Reject)
- **Notification History:** Store notification history locally
- **Advanced Privacy:** Tor support for server communication
- **Rate Limiting:** Client-side notification throttling
- **Custom Sounds:** Per-order-type notification sounds

### Server Repository
The notification server is maintained in a **separate repository** and handles:
- Nostr relay monitoring for new events
- Token decryption and FCM delivery
- Rate limiting and spam protection
- Multiple relay support for redundancy

---

## Testing Strategy

### Unit Tests
- FCM token generation and refresh
- Token encryption/decryption logic
- ECDH key derivation
- Payload padding and parsing

### Integration Tests
- End-to-end notification flow (send → receive → display)
- Background message handling
- Token registration with server
- Notification tap navigation

### Manual Testing
- Test on physical Android devices
- Test with app in foreground/background/closed states
- Test notification permissions flow
- Test enable/disable toggle
- Verify no notifications on Linux builds

---

## Success Metrics

- ✅ Notifications delivered within 5 seconds of new message
- ✅ Background notifications work with app closed
- ✅ Zero message content exposed to Firebase/Google
- ✅ Encrypted tokens successfully registered with server
- ✅ User can completely opt-out of push notifications
- ✅ App compiles and runs on Linux (notifications gracefully disabled)

---

## References

- [MIP-05: Marmot Push Notifications](https://github.com/marmot-protocol/marmot/pull/18) - Privacy-preserving push notification approach
- [mostro-push-server](https://github.com/MostroP2P/mostro-push-server) - Custom notification server repository
- [Firebase Cloud Messaging Documentation](https://firebase.google.com/docs/cloud-messaging)
- [NIP-59: Gift Wrap](https://github.com/nostr-protocol/nips/blob/master/59.md) - Nostr event encryption
- [ChaCha20-Poly1305 AEAD](https://datatracker.ietf.org/doc/html/rfc8439) - Authenticated encryption
- [HKDF Key Derivation](https://datatracker.ietf.org/doc/html/rfc5869) - Key derivation function
