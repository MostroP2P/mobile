# Adding a New Language to Mostro Mobile

This guide explains how to add a new language to the Mostro Mobile Flutter application. The app uses Flutter's internationalization (i18n) system with ARB (Application Resource Bundle) files for translations.

## 📋 Overview

The Mostro Mobile app currently supports:
- **English** (en) - Primary language
- **Spanish** (es) - Secondary language  
- **Italian** (it) - Secondary language

The localization system automatically detects the user's device language and displays the appropriate translations. As of the latest update, the app includes comprehensive localization for:

- **Order Creation Forms** - Amount entry, payment methods, premium settings
- **Account Management** - Key management, privacy settings, trade counters
- **Chat System** - Messages, conversation headers, input fields
- **Trade Details** - Action buttons, status messages, order information
- **Navigation** - Drawer menus, screen titles, button labels

## 🛠 Prerequisites

Before adding a new language, ensure you have:

1. **Flutter SDK** installed and configured
2. **flutter_intl package** (already configured in `pubspec.yaml`)
3. **build_runner package** (already configured in `pubspec.yaml`)
4. **Access to native speakers** or reliable translation tools for accuracy

## 📂 File Structure

The localization files are organized as follows:

```
lib/
├── l10n/                      # Translation source files (ARB)
│   ├── intl_en.arb           # English translations
│   ├── intl_es.arb           # Spanish translations
│   ├── intl_it.arb           # Italian translations
│   └── intl_[NEW].arb        # Your new language file
└── generated/                # Auto-generated files (do not edit)
    ├── l10n.dart             # Main localization class
    ├── l10n_en.dart          # English implementation
    ├── l10n_es.dart          # Spanish implementation
    ├── l10n_it.dart          # Italian implementation
    └── l10n_[NEW].dart       # Auto-generated for new language
```

## 🚀 Step-by-Step Guide

### Step 1: Create the ARB Translation File

1. **Navigate to the l10n directory:**
   ```bash
   cd lib/l10n/
   ```

2. **Create a new ARB file** for your language using the [ISO 639-1 language code](https://en.wikipedia.org/wiki/List_of_ISO_639-1_codes):
   ```bash
   # Example for French
   touch intl_fr.arb
   
   # Example for German  
   touch intl_de.arb
   
   # Example for Portuguese
   touch intl_pt.arb
   ```

3. **Copy the structure from English** as your starting template:
   ```bash
   # Copy English file as template
   cp intl_en.arb intl_fr.arb  # Replace 'fr' with your language code
   ```

### Step 2: Translate the Content

1. **Open your new ARB file** and update the locale identifier:
   ```json
   {
     "@@locale": "fr",  // Change this to your language code
     // ... rest of translations
   }
   ```

2. **Translate all string values** while keeping the keys unchanged:
   ```json
   {
     "@@locale": "fr",
     "login": "Se connecter",                    // Was: "Login"
     "register": "S'inscrire",                  // Was: "Register"
     "buyingBitcoin": "Achat de Bitcoin",       // Was: "Buying Bitcoin"
     "sellingBitcoin": "Vente de Bitcoin",      // Was: "Selling Bitcoin"
     "myActiveTrades": "Mes Échanges Actifs",   // Was: "My Active Trades"
     // ... continue for all keys
   }
   ```

3. **Handle parameterized strings** carefully:
   ```json
   {
     "newOrder": "Votre offre a été publiée ! Veuillez attendre qu'un autre utilisateur choisisse votre commande. Elle sera disponible pendant {expiration_hours} heures.",
     "payInvoice": "Veuillez payer cette facture de retenue de {amount} Sats pour {fiat_code} {fiat_amount} pour commencer l'opération."
   }
   ```

### Step 3: Update Supported Locales

The supported locales are automatically detected from ARB files, but you may need to verify the configuration:

1. **Check `l10n.yaml`** (if it exists) for any manual locale configuration
2. **Verify `pubspec.yaml`** has the required dependencies:
   ```yaml
   dependencies:
     flutter_localizations:
       sdk: flutter
     intl: ^0.20.2
   
   dev_dependencies:
     flutter_intl: ^0.0.1
     build_runner: ^2.4.0
   ```

### Step 4: Generate Localization Files

Run the following command to generate the Dart localization files:

```bash
# Option 1: Using build_runner (recommended)
dart run build_runner build -d

# Option 2: Using flutter (if flutter_intl is properly configured)
flutter packages pub run flutter_intl:generate

# Option 3: Direct flutter command
flutter gen-l10n
```

**Expected output:**
- `lib/generated/l10n_[your_language].dart` will be created
- `lib/generated/l10n.dart` will be updated with new language support

### Step 5: Update App Configuration (if needed)

In most cases, the app will automatically detect and support the new language. However, you may need to add special handling in `lib/core/app.dart`:

```dart
// If you need special locale handling, add it here:
localeResolutionCallback: (locale, supportedLocales) {
  final deviceLocale = locale ?? systemLocale;
  
  // Add special handling for your language if needed
  if (deviceLocale.languageCode == 'fr') {  // Your language code
    return const Locale('fr');
  }
  
  // Check for exact match with any supported locale
  for (var supportedLocale in supportedLocales) {
    if (supportedLocale.languageCode == deviceLocale.languageCode) {
      return supportedLocale;
    }
  }
  
  // Default fallback to English
  return const Locale('en');
}
```

### Step 6: Test the Implementation

1. **Build the app** to ensure everything compiles:
   ```bash
   flutter build apk --debug
   # or
   flutter build ios --debug
   ```

2. **Test locale switching:**
   - Change your device language to the new language
   - Launch the app
   - Verify all text appears in the new language

3. **Test on actual device** with the target language set as system language

## 🧪 Testing Checklist

- [ ] All strings are translated (no English text appears)
- [ ] Parameterized strings work correctly with values
- [ ] App launches without errors
- [ ] Navigation and core functionality work
- [ ] Text fits properly in UI elements (no overflow)
- [ ] Right-to-left languages display correctly (if applicable)
- [ ] App falls back to English for missing translations

## 📝 Translation Guidelines

### Best Practices

1. **Keep context in mind:** Understand where each string appears in the app
2. **Maintain consistency:** Use the same terms throughout the app
3. **Respect character limits:** Some UI elements have space constraints
4. **Use native expressions:** Translate meaning, not just words
5. **Test with real users:** Native speakers can catch nuances

### Key Terminology

When translating, maintain consistency for these core concepts:

- **Bitcoin/BTC** - Usually kept as-is
- **Sats/Satoshis** - May be translated or kept as-is
- **Order** - Trading order (not purchase order)
- **Trade** - Exchange/transaction
- **Fiat** - Traditional currency (USD, EUR, etc.)
- **Lightning** - Bitcoin Lightning Network
- **P2P** - Peer-to-peer
- **HODL** - Bitcoin slang, usually kept as-is

### Handling Parameterized Strings

Some strings contain placeholders like `{amount}`, `{currency}`, `{time}`:

```json
// English
"payInvoice": "Please pay {amount} Sats for {fiat_code} {fiat_amount}"

// French - reorder as needed for natural flow
"payInvoice": "Veuillez payer {amount} Sats pour {fiat_amount} {fiat_code}"

// German - adjust for German word order
"payInvoice": "Bitte zahlen Sie {amount} Sats für {fiat_amount} {fiat_code}"
```

## 🔧 Troubleshooting

### Common Issues

**1. Build errors after adding language:**
```bash
# Clean and regenerate
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

**2. Language not appearing in app:**
- Verify ARB file syntax is valid JSON
- Check that locale code is correct (en, es, fr, de, etc.)
- Ensure all translation keys match the English file exactly

**3. Some strings still in English:**
- Check if the string is hardcoded in Dart files
- Search for untranslated strings: `grep -r "hardcoded text" lib/`
- Ensure all Dart files use `S.of(context)!.keyName` instead of hardcoded strings

**4. Parameterized strings not working:**
- Verify parameter names match exactly: `{amount}` not `{Amount}`
- Check that parameter order makes sense in your language

**5. Right-to-left language issues:**
- Add RTL support in `MaterialApp`:
  ```dart
  MaterialApp(
    // Add this for RTL languages like Arabic, Hebrew
    localizationsDelegates: [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
  )
  ```

### Debug Commands

```bash
# Check supported locales
flutter packages pub run flutter_intl:generate --list-locales

# Validate ARB files
flutter packages pub run flutter_intl:validate

# Clean and rebuild
flutter clean && flutter pub get && dart run build_runner build -d
```

## 🤖 AI Assistant Instructions

If you're an AI helping with localization:

### For Research Tasks:
- Use `Read` tool to examine existing ARB files
- Use `Grep` tool to find hardcoded strings
- Use `LS` tool to understand file structure

### For Implementation Tasks:
1. **Create ARB file:** Use `Write` tool with proper JSON structure
2. **Copy from English:** Use `Read` to get English content, then `Write` new file
3. **Generate files:** Use `Bash` tool to run `dart run build_runner build -d`
4. **Update hardcoded strings:** Use `MultiEdit` tool to replace strings with `S.of(context)!.keyName`
5. **Test compilation:** Use `Bash` tool to run `flutter analyze` and `flutter build`

### Critical Requirements:
- Always preserve ARB file structure and key names
- Never edit files in `lib/generated/` directory
- Always run build commands after ARB changes
- Test compilation before marking task complete
- Add `BuildContext context` parameter to methods that need localization

### Example Workflow:
```
1. Read intl_en.arb to understand structure
2. Write intl_[new].arb with translated content
3. Run: dart run build_runner build -d
4. Search for hardcoded strings in Dart files
5. Replace hardcoded strings with S.of(context)!.keyName
6. Test: flutter analyze && flutter build apk --debug
```

## 📚 Additional Resources

- [Flutter Internationalization Guide](https://docs.flutter.dev/development/accessibility-and-localization/internationalization)
- [ARB File Format Specification](https://github.com/google/app-resource-bundle/wiki/ApplicationResourceBundleSpecification)
- [ISO 639-1 Language Codes](https://en.wikipedia.org/wiki/List_of_ISO_639-1_codes)
- [Material Design Localization](https://material.io/design/usability/bidirectionality.html)

## 🤝 Contributing

When submitting localization contributions:

1. **Test thoroughly** on a device with the target language
2. **Include screenshots** showing the translations in context
3. **Document any cultural adaptations** you made
4. **Get review from native speakers** when possible
5. **Update this guide** if you discover new steps or issues

---

**Example: Adding French Support**

```bash
# 1. Create French ARB file
cp lib/l10n/intl_en.arb lib/l10n/intl_fr.arb

# 2. Edit intl_fr.arb - change @@locale to "fr" and translate all strings

# 3. Generate localization files
dart run build_runner build -d

# 4. Test the build
flutter analyze
flutter build apk --debug

# 5. Test on French device or emulator
```

This will add French support to your Mostro Mobile app! 🇫🇷