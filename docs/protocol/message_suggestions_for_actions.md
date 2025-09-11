# Message Suggestions for Actions

Below are suggestions for messages that clients can show to users when receiving specific actions. These messages can be customized, translated, enhanced with emojis, or modified to provide a better user experience. Clients should replace placeholders in `monospace` format with the corresponding values.

## Actions

- **new-order:**  
  Your offer has been published! Please wait until another user picks your order. It will be available for `expiration_hours` hours. You can cancel this order before another user picks it up by executing: `cancel`.

- **canceled:**  
  You have canceled the order ID: `id`.

- **pay-invoice:**  
  Please pay this hold invoice of `amount` Sats for `fiat_code` `fiat_amount` to start the operation. If you do not pay it within `expiration_seconds`, the trade will be canceled.

- **add-invoice:**  
  Please send me an invoice for `amount` satoshis equivalent to `fiat_code` `fiat_amount`. This is where I will send the funds upon trade completion. If you don’t provide the invoice within `expiration_seconds`, the trade will be canceled.

- **waiting-seller-to-pay:**  
  Please wait. I’ve sent a payment request to the seller to send the Sats for the order ID: `id`. If the seller doesn’t complete the payment within `expiration_seconds`, the trade will be canceled.

- **waiting-buyer-invoice:**  
  Payment received! Your Sats are now "held" in your wallet. I’ve requested the buyer to provide an invoice. If they don’t do so within `expiration_seconds`, your Sats will return to your wallet, and the trade will be canceled.

- **buyer-invoice-accepted:**  
  The invoice has been successfully saved.

- **hold-invoice-payment-accepted:**  
  Contact the seller at `seller-npub` to arrange how to send `fiat_code` `fiat_amount` using `payment_method`. Once you send the fiat money, notify me with `fiat-sent`.

- **buyer-took-order:**  
  Contact the buyer at `buyer-npub` to inform them how to send `fiat_code` `fiat_amount` through `payment_method`. You’ll be notified when the buyer confirms the fiat payment. Afterward, you should verify if it has arrived. If the buyer does not respond, you can initiate a cancellation or a dispute. Remember, an administrator will NEVER contact you to resolve your order unless you open a dispute first.

- **fiat-sent-ok:**  
  - _To the buyer:_ I have informed `seller-npub` that you sent the fiat money. If the seller confirms receipt, they will release the funds. If they refuse, you can open a dispute. 
  - _To the seller:_ `buyer-npub` has informed you that they sent the fiat money. Once you confirm receipt, release the funds. After releasing, the money will go to the buyer and there will be no turning back, so only proceed if you are sure. If you want to release the Sats to the buyer, send me `release-order-message`.  

- **released:**  
  `seller-npub` has released the Sats! Expect your invoice to be paid shortly. Ensure your wallet is online to receive via Lightning Network.

- **purchase-completed:**  
  Your purchase of Bitcoin has been completed successfully. Your invoice has been paid. Enjoy sound money!

- **hold-invoice-payment-settled:**  
  Your sale of Bitcoin has been completed after confirming the payment from `buyer-npub`.

- **rate:**  
  Please rate your counterparty.

- **rate-received:**  
  The rating has been successfully saved.

- **cooperative-cancel-initiated-by-you:**  
  You’ve initiated the cancellation of order ID: `id`. Your counterparty must agree. If they do not respond, you can open a dispute. Note that no administrator will contact you regarding this cancellation unless you open a dispute first.

- **cooperative-cancel-initiated-by-peer:**  
  Your counterparty wants to cancel order ID: `id`. Send `cancel-order-message` to confirm. Note that no administrator will contact you regarding this cancellation unless you open a dispute first. If you agree on such cancellation, please send me `cancel-order-message`.

- **cooperative-cancel-accepted:**  
  Order ID: `id` has been successfully canceled.

- **dispute-initiated-by-you:**  
  You’ve initiated a dispute for order ID: `id`. A solver will be assigned soon. Once assigned, I will share their npub with you, and only they will be able to assist you. You may contact the solver directly.

- **dispute-initiated-by-peer:**  
  Your counterparty initiated a dispute for order ID: `id`. A solver will be assigned soon. Once assigned, I will share their npub with you, and only they will be able to assist you. You may contact the solver directly.

- **admin-took-dispute:**  
  - _Admin:_ Here are the details of the dispute: `details`. You need to determine which user is correct and decide whether to cancel or complete the order. Please note that your decision will be final and cannot be reversed.
  - _Users:_ Solver `admin-npub` will handle your dispute. You can contact them directly.

- **admin-canceled:**  
  - _Admin:_ You have canceled order ID: `id`.  
  - _Users:_ The admin has canceled order ID: `id`.

- **admin-settled:**  
  - _Admin:_ You have completed order ID: `id`.  
  - _Users:_ The admin has completed order ID: `id`.

- **payment-failed:**  
  I couldn’t send the Sats. I’ll retry `payment_attempts` times in `payment_retries_interval` minutes. Please ensure your node/wallet is online.

- **invoice-updated:**  
  The invoice has been successfully updated.

- **hold-invoice-payment-canceled:**  
  The invoice was canceled. Your Sats are available in your wallet again.

- **admin-add-solver:**  
  Solver `npub` has been successfully added.

- **cant-do:**  
  You are not allowed to perform the action: `action`.


## Cant Do Reasons

Mostro also handles messages with the `CantDo` action for various reasons. The details of the failure are included in the payload section of the event, providing a structured explanation of the issue. Below are suggested texts that clients can display to users based on the `CantDo` reason received:

- **invalid-trade-index:**  
  The provided trade index is invalid. Please ensure your client is synchronized and try again.

- **invalid-amount:**  
  The provided amount is invalid. Please verify it and try again.

- **invalid-invoice:**  
  The provided Lightning invoice is invalid. Please check the invoice details and try again.

- **invalid-peer:**  
  You are not authorized to perform this action.

- **invalid-order-status:**  
  The action cannot be completed due to the current order status. 

- **invalid-parameters:**  
  The action cannot be completed due to invalid parameters. Please review the provided values and try again.

- **invalid-pubkey:**  
  The action cannot be completed because the public key is invalid.

- **order-already-canceled:**  
  The action cannot be completed because the order has already been canceled.

- **cant-create-user:**  
  The action cannot be completed because the user could not be created.

- **is-not-your-dispute:**  
  This dispute is not assigned to you.

- **not-found:**  
  The requested dispute could not be found.

- **invalid-signature:**  
  The action cannot be completed because the signature is invalid.

- **is-not-your-order:**  
  This order does not belong to you.

- **not-allowed-by-status:**  
  The action cannot be completed because order Id `id` status is `order-status`.  

- **out-of-range-fiat-amount:**  
  The requested fiat amount is outside the acceptable range (`min_amount`–`max_amount`).

- **out-of-range-sats-amount:**  
  The allowed Sats amount for this Mostro is between min `min_order_amount` and max `max_order_amount`. Please enter an amount within this range.