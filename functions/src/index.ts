import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {onRequest} from "firebase-functions/v2/https";
import WebSocket from "ws";

admin.initializeApp();

const NOSTR_RELAYS = ["wss://relay.mostro.network"];
const MOSTRO_PUBKEY = "82fa8cb978b43c79b2156585bac2c011176a21d2aead6d9f7c575c005be88390";
const FCM_TOPIC = "mostro_notifications";
const SUBSCRIPTION_ID = "mostro-poller";

let lastCheckTimestamp = Math.floor(Date.now() / 1000);

function pollRelay(relayUrl: string): Promise<number> {
  return new Promise((resolve, reject) => {
    let eventCount = 0;
    let timeoutHandle: NodeJS.Timeout | undefined;

    try {
      logger.info(`Polling relay: ${relayUrl}`);

      const ws = new WebSocket(relayUrl);

      timeoutHandle = setTimeout(() => {
        logger.warn(`Polling timeout for ${relayUrl}`);
        ws.close();
        resolve(eventCount);
      }, 30000);

      ws.on("open", () => {
        logger.info(`Connected to ${relayUrl}`);

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

          if (message[0] === "EVENT" && message[1] === SUBSCRIPTION_ID) {
            const event = message[2];

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

async function sendSilentPushNotification(): Promise<void> {
  try {
    const now = Date.now();

    const message = {
      topic: FCM_TOPIC,
      data: {
        type: "silent_wake",
        timestamp: now.toString(),
      },
      android: {
        priority: "high" as const,
        notification: undefined,
      },
      apns: {
        headers: {
          "apns-priority": "5",
          "apns-push-type": "background",
          "apns-topic": "network.mostro.app",
        },
        payload: {
          aps: {
            contentAvailable: true,
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

export const sendTestNotification = onRequest(async (_req, res) => {
  try {
    await sendSilentPushNotification();
    res.json({success: true, message: "Test notification sent"});
  } catch (error) {
    logger.error("Error in sendTestNotification:", error);
    res.status(500).json({success: false, error: String(error)});
  }
});

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

export const keepAlive = onSchedule("every 1 minutes", async () => {
  const checkStartTime = Math.floor(Date.now() / 1000);
  logger.info("Starting scheduled relay poll", {
    lastCheckTimestamp,
    lastCheckDate: new Date(lastCheckTimestamp * 1000).toISOString(),
    checkStartDate: new Date(checkStartTime * 1000).toISOString(),
  });

  try {
    const pollPromises = NOSTR_RELAYS.map((relayUrl) => pollRelay(relayUrl));
    const results = await Promise.allSettled(pollPromises);

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

    if (totalNewEvents > 0) {
      logger.info(`Found ${totalNewEvents} new events, sending notification`);
      await sendSilentPushNotification();
    } else {
      logger.info("No new events found, skipping notification");
    }

    lastCheckTimestamp = checkStartTime;
  } catch (error) {
    logger.error("Error in keepAlive poll:", error);
  }
});

logger.info("Mostro FCM Cloud Function initialized (polling mode)");
