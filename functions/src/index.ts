/**
 * Firebase Cloud Function for Mostro Mobile Push Notifications
 *
 * This function listens to Nostr relays for new kind 1059 (gift-wrapped) events
 * and sends silent push notifications via FCM to wake up the mobile app.
 *
 * Privacy-preserving approach:
 * - No event data sent via FCM
 * - No user-to-token mapping needed
 * - All devices receive the same empty notification
 * - App fetches and decrypts events locally
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import {onSchedule} from "firebase-functions/v2/scheduler";
import WebSocket from "ws";

// Initialize Firebase Admin SDK
admin.initializeApp();

// Configuration - Mostro relay from lib/core/config.dart
const NOSTR_RELAYS = [
  "wss://relay.mostro.network",
];

// FCM topic that all app instances subscribe to
const FCM_TOPIC = "mostro_notifications";

// Track last notification time to prevent spam (1 minute cooldown)
let lastNotificationTime = 0;
const NOTIFICATION_COOLDOWN_MS = 60 * 1000; // 1 minute

// WebSocket connections to relays
const relayConnections = new Map<string, WebSocket>();

// Subscription ID for tracking
const SUBSCRIPTION_ID = "mostro-listener";

/**
 * Connects to a Nostr relay and subscribes to kind 1059 events
 */
function connectToRelay(relayUrl: string): void {
  try {
    logger.info(`Connecting to relay: ${relayUrl}`);

    const ws = new WebSocket(relayUrl);

    ws.on("open", () => {
      logger.info(`Connected to ${relayUrl}`);

      // Subscribe to kind 1059 (gift-wrapped) events
      // Only listen for events from the last 5 minutes to avoid processing old events
      const fiveMinutesAgo = Math.floor(Date.now() / 1000) - 300;

      const subscriptionMessage = JSON.stringify([
        "REQ",
        SUBSCRIPTION_ID,
        {
          kinds: [1059],
          since: fiveMinutesAgo,
        },
      ]);

      ws.send(subscriptionMessage);
      logger.info(`Subscribed to kind 1059 events on ${relayUrl}`);
    });

    ws.on("message", (data: WebSocket.Data) => {
      try {
        const message = JSON.parse(data.toString());

        // Check if this is an EVENT message
        if (message[0] === "EVENT" && message[1] === SUBSCRIPTION_ID) {
          const event = message[2];

          // Verify it's a kind 1059 event
          if (event.kind === 1059) {
            logger.info(`Received kind 1059 event from ${relayUrl}`, {
              eventId: event.id,
              createdAt: event.created_at,
            });

            // Send FCM notification to wake up all devices
            sendSilentPushNotification();
          }
        }
      } catch (error) {
        logger.error(`Error processing message from ${relayUrl}:`, error);
      }
    });

    ws.on("error", (error: Error) => {
      logger.error(`WebSocket error on ${relayUrl}:`, error);
    });

    ws.on("close", () => {
      logger.warn(`Connection closed to ${relayUrl}, reconnecting in 5 seconds...`);
      relayConnections.delete(relayUrl);

      // Reconnect after 5 seconds
      setTimeout(() => connectToRelay(relayUrl), 5000);
    });

    relayConnections.set(relayUrl, ws);
  } catch (error) {
    logger.error(`Failed to connect to ${relayUrl}:`, error);

    // Retry connection after 10 seconds
    setTimeout(() => connectToRelay(relayUrl), 10000);
  }
}

/**
 * Sends a silent push notification to all subscribed devices
 * Uses FCM topic messaging to broadcast to all users
 */
async function sendSilentPushNotification(): Promise<void> {
  try {
    // Check cooldown to prevent notification spam
    const now = Date.now();
    if (now - lastNotificationTime < NOTIFICATION_COOLDOWN_MS) {
      logger.info("Skipping notification due to cooldown");
      return;
    }

    lastNotificationTime = now;

    // Send silent data-only message to FCM topic
    const message = {
      topic: FCM_TOPIC,
      data: {
        // Empty payload - just wake up the app
        type: "silent_wake",
        timestamp: now.toString(),
      },
      android: {
        priority: "high" as const,
        // Silent notification - no sound, no vibration
        notification: undefined,
      },
      apns: {
        headers: {
          "apns-priority": "10",
        },
        payload: {
          aps: {
            contentAvailable: true,
            // Silent notification for iOS
            sound: undefined,
          },
        },
      },
    };

    const response = await admin.messaging().send(message);
    logger.info("Silent push notification sent successfully", {
      messageId: response,
      topic: FCM_TOPIC,
    });
  } catch (error) {
    logger.error("Error sending FCM notification:", error);
  }
}

/**
 * HTTP endpoint to manually trigger a test notification
 * Useful for testing the FCM setup
 */
export const sendTestNotification = functions.https.onRequest(async (_req, res) => {
  try {
    await sendSilentPushNotification();
    res.json({ success: true, message: "Test notification sent" });
  } catch (error) {
    logger.error("Error in sendTestNotification:", error);
    res.status(500).json({ success: false, error: String(error) });
  }
});

/**
 * HTTP endpoint to get connection status
 */
export const getStatus = functions.https.onRequest((_req, res) => {
  const status = {
    connectedRelays: Array.from(relayConnections.keys()),
    totalRelays: NOSTR_RELAYS.length,
    lastNotificationTime: new Date(lastNotificationTime).toISOString(),
  };

  res.json(status);
});

/**
 * Initialize relay connections when the function starts
 * This keeps persistent WebSocket connections to Nostr relays
 */
export const startNostrListener = functions.https.onRequest((_req, res) => {
  if (relayConnections.size === 0) {
    logger.info("Starting Nostr relay listener...");

    // Connect to all configured relays
    NOSTR_RELAYS.forEach((relayUrl) => {
      connectToRelay(relayUrl);
    });

    res.json({
      success: true,
      message: "Nostr listener started",
      relays: NOSTR_RELAYS,
    });
  } else {
    res.json({
      success: true,
      message: "Nostr listener already running",
      connectedRelays: Array.from(relayConnections.keys()),
    });
  }
});

/**
 * Scheduled function to keep connections alive
 * Runs every 5 minutes to ensure connections are maintained
 */
export const keepAlive = onSchedule("every 5 minutes", async (_event) => {
  logger.info("Keep-alive check running...");

  // Check and reconnect to any disconnected relays
  NOSTR_RELAYS.forEach((relayUrl) => {
    if (!relayConnections.has(relayUrl)) {
      logger.warn(`Relay ${relayUrl} is disconnected, reconnecting...`);
      connectToRelay(relayUrl);
    }
  });
});

// Auto-start connections when the module loads
// This ensures connections are established when the function is deployed
NOSTR_RELAYS.forEach((relayUrl) => {
  connectToRelay(relayUrl);
});

logger.info("Mostro FCM Cloud Function initialized");
