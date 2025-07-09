class HighlightConfig {
  final String pattern;
  const HighlightConfig({required this.pattern});

  static const firstStep = HighlightConfig(
    pattern: r'\b(Nostr|no KYC|sin KYC|senza KYC|censorship-resistant|resistente a la censura|resistente alla censura)\b',
  );

  static const privacy = HighlightConfig(
    pattern: r'\b(Reputation mode|Full privacy mode|Modo reputación|Modo privacidad completa|Modalità reputazione|Modalità privacy completa)\b',
  );

  static const security = HighlightConfig(
    pattern: r'\b(Hold Invoices|Facturas de Retención|Fatture di Blocco)\b',
  );

  static const chat = HighlightConfig(
    pattern: r'\b(end-to-end encrypted|encriptado de extremo a extremo|crittografata end-to-end)\b',
  );

  static const orderBook = HighlightConfig(
    pattern: r'\b(order book|libro de órdenes|libro ordini)\b',
  );
}
