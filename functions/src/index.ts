/**
 * Firebase Cloud Function for Mostro Mobile Push Notifications
 *
 * This function polls Nostr relays for new kind 1059 (gift-wrapped) events
 * and sends silent push notifications via FCM to wake up the mobile app.
 *
 * Privacy-preserving approach:
 * - No event data sent via FCM
 * - No user-to-token mapping needed
 * - All devices receive the same empty notification
 * - App fetches and decrypts events locally
 *
 * Polling-based architecture:
 * - Scheduled function runs every 5 minutes
 * - Queries relay for new events since last check
 * - Closes connection immediately after receiving response
 * - No persistent WebSocket connections
 */

import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {onRequest} from "firebase-functions/v2/https";
import WebSocket from "ws";

// Initialize Firebase Admin SDK
admin.initializeApp();

// Configuration - Mostro relay from lib/core/config.dart
const NOSTR_RELAYS = [
  "wss://relay.mostro.network",
];

// Mostro instance public key - matches lib/core/config.dart
// This filters events to only those from your Mostro instance
const MOSTRO_PUBKEY =
  "82fa8cb978b43c79b2156585bac2c011176a21d2aead6d9f7c575c005be88390";

// FCM topic that all app instances subscribe to
const FCM_TOPIC = "mostro_notifications";

// Track last check time to query for new events
let lastCheckTimestamp = Math.floor(Date.now() / 1000);

// Subscription ID for tracking
const SUBSCRIPTION_ID = "mostro-poller";

/**
 * Polls a Nostr relay for new events since the last check
 * Opens connection, queries, waits for response, then closes
 * @param {string} relayUrl - The WebSocket URL of the Nostr relay
 * @return {Promise<number>} Number of new events found
 */
function pollRelay(relayUrl: string): Promise<number> {
  return new Promise((resolve, reject) => {
    let eventCount = 0;
    let timeoutHandle: NodeJS.Timeout | undefined;

    try {
      logger.info(`Polling relay: ${relayUrl}`);

      const ws = new WebSocket(relayUrl);

      // Set timeout for the entire operation (30 seconds)
      timeoutHandle = setTimeout(() => {
        logger.warn(`Polling timeout for ${relayUrl}`);
        ws.close();
        resolve(eventCount);
      }, 30000);

      ws.on("open", () => {
        logger.info(`Connected to ${relayUrl}`);

        // Query for events since last check
        const subscriptionMessage = JSON.stringify([
          "REQ",
          SUBSCRIPTION_ID,
          {
            kinds: [1059],
            authors: [MOSTRO_PUBKEY],
            since: lastCheckTimestamp,
          },
        ]);

        ws.send(subscriptionMessage);
        logger.info(`Querying events since ${lastCheckTimestamp}`, {
          sinceDate: new Date(lastCheckTimestamp * 1000).toISOString(),
        });
      });

      ws.on("message", (data: WebSocket.Data) => {
        try {
          const message = JSON.parse(data.toString());

          // Check if this is an EVENT message
          if (message[0] === "EVENT" && message[1] === SUBSCRIPTION_ID) {
            const event = message[2];

            // Verify it's a kind 1059 event
            if (event.kind === 1059) {
              eventCount++;
              logger.info(`Found new event from ${relayUrl}`, {
                eventId: event.id,
                author: event.pubkey,
                createdAt: event.created_at,
                timestamp: new Date(event.created_at * 1000).toISOString(),
              });
            }
          } else if (message[0] === "EOSE") {
            logger.info(`Polling complete for ${relayUrl}`, {
              eventsFound: eventCount,
            });

            // Close connection after receiving EOSE
            clearTimeout(timeoutHandle);
            ws.close();
            resolve(eventCount);
          }
        } catch (error) {
          logger.error(`Error processing message from ${relayUrl}:`, error);
        }
      });

      ws.on("error", (error: Error) => {
        logger.error(`WebSocket error on ${relayUrl}:`, error);
        clearTimeout(timeoutHandle);
        reject(error);
      });

      ws.on("close", () => {
        clearTimeout(timeoutHandle);
        logger.debug(`Connection to ${relayUrl} closed`);
      });
    } catch (error) {
      if (timeoutHandle) {
        clearTimeout(timeoutHandle);
      }
      logger.error(`Failed to poll ${relayUrl}:`, error);
      reject(error);
    }
  });
}

/**
 * Sends a silent push notification to all subscribed devices
 * Uses FCM topic messaging to broadcast to all users
 */
async function sendSilentPushNotification(): Promise<void> {
  try {
    const now = Date.now();

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
      timestamp: new Date(now).toISOString(),
    });
  } catch (error) {
    logger.error("Error sending FCM notification:", error);
  }
}

/**
 * HTTP endpoint to manually trigger a test notification
 * Useful for testing the FCM setup
 */
export const sendTestNotification = onRequest(async (_req, res) => {
  try {
    await sendSilentPushNotification();
    res.json({success: true, message: "Test notification sent"});
  } catch (error) {
    logger.error("Error in sendTestNotification:", error);
    res.status(500).json({success: false, error: String(error)});
  }
});

/**
 * HTTP endpoint to get polling status
 */
export const getStatus = onRequest((_req, res) => {
  const status = {
    relays: NOSTR_RELAYS,
    lastCheckTimestamp: lastCheckTimestamp,
    lastCheckDate: new Date(lastCheckTimestamp * 1000).toISOString(),
    mostroPublicKey: MOSTRO_PUBKEY,
    fcmTopic: FCM_TOPIC,
  };

  res.json(status);
});

/**
 * Scheduled function to poll relays for new events
 * Runs every 5 minutes to check for new Mostro notifications
 */
export const keepAlive = onSchedule("every 5 minutes", async () => {
  const checkStartTime = Math.floor(Date.now() / 1000);
  logger.info("Starting scheduled relay poll", {
    lastCheckTimestamp,
    lastCheckDate: new Date(lastCheckTimestamp * 1000).toISOString(),
    checkStartDate: new Date(checkStartTime * 1000).toISOString(),
  });

  try {
    // Poll all configured relays
    const pollPromises = NOSTR_RELAYS.map((relayUrl) => pollRelay(relayUrl));
    const results = await Promise.allSettled(pollPromises);

    // Count total new events
    let totalNewEvents = 0;
    results.forEach((result, index) => {
      if (result.status === "fulfilled") {
        totalNewEvents += result.value;
        const relay = NOSTR_RELAYS[index];
        logger.info(`Relay ${relay} found ${result.value} events`);
      } else {
        logger.error(
          `Relay ${NOSTR_RELAYS[index]} polling failed:`,
          result.reason
        );
      }
    });

    logger.info("Polling complete", {
      totalNewEvents,
      relaysChecked: NOSTR_RELAYS.length,
    });

    // Send notification if we found new events
    if (totalNewEvents > 0) {
      logger.info(`Found ${totalNewEvents} new events, sending notification`);
      await sendSilentPushNotification();
    } else {
      logger.info("No new events found, skipping notification");
    }

    // Update last check timestamp for next poll
    lastCheckTimestamp = checkStartTime;
  } catch (error) {
    logger.error("Error in keepAlive poll:", error);
  }
});

logger.info("Mostro FCM Cloud Function initialized (polling mode)");
