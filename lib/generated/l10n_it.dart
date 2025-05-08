// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class SIt extends S {
  SIt([String locale = 'it']) : super(locale);

  @override
  String newOrder(Object expiration_hours) {
    return 'La tua offerta è stata pubblicata! Attendi fino a quando un altro utente accetta il tuo ordine. Sarà disponibile per $expiration_hours ore. Puoi annullare questo ordine prima che un altro utente lo prenda premendo: Cancella.';
  }

  @override
  String canceled(Object id) {
    return 'Hai annullato l\'ordine ID: $id!';
  }

  @override
  String payInvoice(Object amount, Object expiration_seconds, Object fiat_amount, Object fiat_code) {
    return 'Paga questa Hodl Invoice di $amount Sats per $fiat_amount $fiat_code per iniziare l\'operazione. Se non la paghi entro $expiration_seconds lo scambio sarà annullato.';
  }

  @override
  String addInvoice(Object amount, Object expiration_seconds, Object fiat_amount, Object fiat_code) {
    return 'Inserisci una Invoice bolt11 di $amount satoshi equivalente a $fiat_amount $fiat_code. Questa invoice riceverà i fondi una volta completato lo scambio. Se non fornisci una invoice entro $expiration_seconds questo scambio sarà annullato.';
  }

  @override
  String waitingSellerToPay(Object expiration_seconds, Object id) {
    return 'Attendi un momento per favore. Ho inviato una richiesta di pagamento al venditore per rilasciare i Sats per l\'ordine ID $id. Una volta effettuato il pagamento, vi connetterò entrambi. Se il venditore non completa il pagamento entro $expiration_seconds minuti lo scambio sarà annullato.';
  }

  @override
  String waitingBuyerInvoice(Object expiration_seconds) {
    return 'Pagamento ricevuto! I tuoi Sats sono ora \'custoditi\' nel tuo portafoglio. Attendi un momento per favore. Ho richiesto all\'acquirente di fornire una invoice lightning. Una volta ricevuta, vi connetterò entrambi, altrimenti se non la riceviamo entro $expiration_seconds i tuoi Sats saranno nuovamente disponibili nel tuo portafoglio e lo scambio sarà annullato.';
  }

  @override
  String get buyerInvoiceAccepted => 'Fattura salvata con successo!';

  @override
  String holdInvoicePaymentAccepted(Object fiat_amount, Object fiat_code, Object payment_method, Object seller_npub) {
    return 'Contatta il venditore tramite la sua npub $seller_npub ed ottieni i dettagli per inviare il pagamento di $fiat_amount $fiat_code utilizzando $payment_method. Una volta inviato il pagamento, clicca: Pagamento inviato';
  }

  @override
  String buyerTookOrder(Object buyer_npub, Object fiat_amount, Object fiat_code, Object payment_method) {
    return 'Contatta l\'acquirente, ecco il suo npub $buyer_npub, per informarlo su come inviarti $fiat_amount $fiat_code tramite $payment_method. Riceverai una notifica una volta che l\'acquirente indicherà che il pagamento fiat è stato inviato. Successivamente, dovresti verificare se sono arrivati i fondi. Se l\'acquirente non risponde, puoi iniziare l\'annullamento dell\'ordine o una disputa. Ricorda, un amministratore NON ti contatterà per risolvere il tuo ordine a meno che tu non apra prima una disputa.';
  }

  @override
  String fiatSentOkBuyer(Object seller_npub) {
    return 'Ho informato $seller_npub che hai inviato il pagamento. Quando il venditore confermerà di aver ricevuto il tuo pagamento, dovrebbe rilasciare i fondi. Se rifiuta, puoi aprire una disputa.';
  }

  @override
  String fiatSentOkSeller(Object buyer_npub) {
    return '$buyer_npub ha confermato di aver inviato il pagamento. Una volta confermato la ricezione dei fondi fiat, puoi rilasciare i Sats. Dopo il rilascio, i Sats andranno all\'acquirente, l\'azione è irreversibile, quindi procedi solo se sei sicuro. Se vuoi rilasciare i Sats all\'acquirente, premi: Rilascia Fondi.';
  }

  @override
  String released(Object seller_npub) {
    return '$seller_npub ha già rilasciato i Sats! Aspetta solo che la tua invoice venga pagata. Ricorda, il tuo portafoglio deve essere online per ricevere i fondi tramite Lightning Network.';
  }

  @override
  String get purchaseCompleted => 'L\'acquisto di nuovi satoshi è stato completato con successo. Goditi questi dolci Sats!';

  @override
  String holdInvoicePaymentSettled(Object buyer_npub) {
    return 'Il tuo scambio di vendita di Sats è stato completato dopo aver confermato il pagamento da $buyer_npub.';
  }

  @override
  String get rate => 'Dai una valutazione alla controparte';

  @override
  String get rateReceived => 'Valutazione salvata con successo!';

  @override
  String cooperativeCancelInitiatedByYou(Object id) {
    return 'Hai iniziato l\'annullamento dell\'ordine ID: $id. La tua controparte deve anche concordare l\'annullamento. Se non risponde, puoi aprire una disputa. Nota che nessun amministratore ti contatterà MAI riguardo questo annullamento a meno che tu non apra prima una disputa.';
  }

  @override
  String cooperativeCancelInitiatedByPeer(Object id) {
    return 'La tua controparte vuole annullare l\'ordine ID: $id. Nota che nessun amministratore ti contatterà MAI riguardo questo annullamento a meno che tu non apra prima una disputa. Se concordi su tale annullamento, premi: Annulla Ordine.';
  }

  @override
  String cooperativeCancelAccepted(Object id) {
    return 'L\'ordine $id è stato annullato con successo!';
  }

  @override
  String disputeInitiatedByYou(Object id, Object user_token) {
    return 'Hai iniziato una disputa per l\'ordine ID: $id. Un amministratore sarà assegnato presto alla tua disputa. Una volta assegnato, riceverai il suo npub e solo questo account potrà assisterti. Devi contattare l\'amministratore direttamente, ma se qualcuno ti contatta prima, assicurati di chiedergli di fornirti il token per la tua disputa. Il token di questa disputa è: $user_token.';
  }

  @override
  String disputeInitiatedByPeer(Object id, Object user_token) {
    return 'La tua controparte ha iniziato una disputa per l\'ordine ID: $id. Un amministratore sarà assegnato presto alla tua disputa. Una volta assegnato, ti condividerò il loro npub e solo loro potranno assisterti. Devi contattare l\'amministratore direttamente, ma se qualcuno ti contatta prima, assicurati di chiedergli di fornirti il token per la tua disputa. Il token di questa disputa è: $user_token.';
  }

  @override
  String adminTookDisputeAdmin(Object details) {
    return 'Ecco i dettagli dell\'ordine della disputa che hai preso: $details. Devi determinare quale utente ha ragione e decidere se annullare o completare l\'ordine. Nota che la tua decisione sarà finale e non può essere annullata.';
  }

  @override
  String adminTookDisputeUsers(Object admin_npub) {
    return 'L\'amministratore $admin_npub gestirà la tua disputa. Devi contattare l\'amministratore direttamente, ma se qualcuno ti contatta prima, assicurati di chiedergli di fornirti il token per la tua disputa..';
  }

  @override
  String adminCanceledAdmin(Object id) {
    return 'Hai annullato l\'ordine ID: $id!';
  }

  @override
  String adminCanceledUsers(Object id) {
    return 'L\'amministratore ha annullato l\'ordine ID: $id!';
  }

  @override
  String adminSettledAdmin(Object id) {
    return 'Hai completato l\'ordine ID: $id!';
  }

  @override
  String adminSettledUsers(Object id) {
    return 'L\'amministratore ha completato l\'ordine ID: $id!';
  }

  @override
  String paymentFailed(Object payment_attempts, Object payment_retries_interval) {
    return 'Ho provato a inviarti i Sats ma il pagamento della tua invoice è fallito. Tenterò $payment_attempts volte ancora ogni $payment_retries_interval minuti. Per favore assicurati che il tuo nodo/portafoglio lightning sia online.';
  }

  @override
  String get invoiceUpdated => 'Invoice aggiornata con successo!';

  @override
  String get holdInvoicePaymentCanceled => 'Invoice annullata; i tuoi Sats saranno nuovamente disponibili nel tuo portafoglio.';

  @override
  String cantDo(Object action) {
    return 'Non sei autorizzato a $action per questo ordine!';
  }

  @override
  String adminAddSolver(Object npub) {
    return 'Hai aggiunto con successo l\'amministratore $npub.';
  }

  @override
  String get invalidSignature => 'L\'azione non può essere completata perché la firma non è valida.';

  @override
  String get invalidTradeIndex => 'L\'indice di scambio fornito non è valido. Assicurati che il tuo client sia sincronizzato e riprova.';

  @override
  String get invalidAmount => 'L\'importo fornito non è valido. Verificalo e riprova.';

  @override
  String get invalidInvoice => 'La fattura Lightning fornita non è valida. Controlla i dettagli della fattura e riprova.';

  @override
  String get invalidPaymentRequest => 'La richiesta di pagamento non è valida o non può essere elaborata.';

  @override
  String get invalidPeer => 'Non sei autorizzato ad eseguire questa azione.';

  @override
  String get invalidRating => 'Il valore della valutazione è non valido o fuori dal range consentito.';

  @override
  String get invalidTextMessage => 'Il messaggio di testo non è valido o contiene contenuti proibiti.';

  @override
  String get invalidOrderKind => 'Il tipo di ordine non è valido.';

  @override
  String get invalidOrderStatus => 'L\'azione non può essere completata a causa dello stato attuale dell\'ordine.';

  @override
  String get invalidPubkey => 'L\'azione non può essere completata perché la chiave pubblica non è valida.';

  @override
  String get invalidParameters => 'L\'azione non può essere completata a causa di parametri non validi. Rivedi i valori forniti e riprova.';

  @override
  String get orderAlreadyCanceled => 'L\'azione non può essere completata perché l\'ordine è già stato annullato.';

  @override
  String get cantCreateUser => 'L\'azione non può essere completata perché l\'utente non può essere creato.';

  @override
  String get isNotYourOrder => 'Questo ordine non appartiene a te.';

  @override
  String notAllowedByStatus(Object id, Object order_status) {
    return 'Non sei autorizzato ad eseguire questa azione perché lo stato dell\'ordine ID $id è $order_status.';
  }

  @override
  String outOfRangeFiatAmount(Object max_amount, Object min_amount) {
    return 'L\'importo richiesto è errato e potrebbe essere fuori dai limiti accettabili. Il limite minimo è $min_amount e il limite massimo è $max_amount.';
  }

  @override
  String outOfRangeSatsAmount(Object max_order_amount, Object min_order_amount) {
    return 'L\'importo consentito per gli ordini di questo Mostro è compreso tra min $min_order_amount e max $max_order_amount Sats. Inserisci un importo all\'interno di questo range.';
  }

  @override
  String get isNotYourDispute => 'Questa disputa non è assegnata a te!';

  @override
  String get disputeCreationError => 'Non è possibile avviare una disputa per questo ordine.';

  @override
  String get notFound => 'Disputa non trovata.';

  @override
  String get invalidDisputeStatus => 'Lo stato della disputa è invalido.';

  @override
  String get invalidAction => 'L\'azione richiesta è invalida';

  @override
  String get pendingOrderExists => 'Esiste già un ordine in attesa.';
}
