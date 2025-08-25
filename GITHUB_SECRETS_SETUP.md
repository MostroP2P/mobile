# GitHub Secrets Setup for Android APK Signing

This guide walks you through setting up secure Android APK signing in GitHub Actions from scratch. No prior knowledge assumed.

## What This Guide Achieves

By the end, you'll have:
- ✅ Properly signed APKs built in GitHub Actions
- ✅ Consistent signing certificates across all builds
- ✅ Secure credential storage in GitHub Secrets
- ✅ APK installation that works without uninstalling previous versions

## Overview

Android APKs must be signed with a certificate to install on devices. For app updates to work, all versions must use the same signing certificate. This guide ensures your GitHub Actions builds use the same certificate as your local builds.

## Step 0: Prerequisites and Setup

### What You Need

Before starting, you need:
- ✅ Android keystore file (`.jks` or `.keystore` file) - **we'll help you create one if needed**
- ✅ Keystore passwords and alias - **you'll choose these during creation**
- ✅ Access to your GitHub repository settings

**Don't worry if you don't have a keystore yet - this guide covers creating one from scratch!**

### Check for Existing Keystore

First, determine if you already have a keystore file:

**Search for existing keystore files:**
```bash
# Navigate to your Flutter project root
cd /path/to/your/flutter/project

# Look for keystore files in common locations
find . -name "*.jks" -o -name "*.keystore" -o -name "*.p12"

# Check the most common location
ls -la android/app/
```

**Common keystore file locations:**
- `android/app/upload-keystore.jks`
- `android/app/key.jks`
- `android/keystore.jks`
- `android/release-key.jks`

**If you find keystore files:**
- ✅ **You have a keystore** → Skip to "Create/Update key.properties" section below
- ❓ **Multiple keystores found** → Use the one related to your app (usually contains "upload" or your app name)
- 📁 **Only debug keystores found** → These won't work for release builds, create a new one

**If no keystore files found:**
- ❌ **No keystore exists** → Continue to "Create Your Keystore" section below

### Create Your Keystore (If You Don't Have One)

If you need to create a new keystore, follow these steps carefully:

#### Choose Your Keystore Parameters

Before creating the keystore, decide on these values:

**Passwords (choose strong, memorable passwords):**
- **Store Password**: Protects the keystore file (e.g., `MyApp2025SecurePassword`)
- **Key Password**: Protects the signing key (can be same as store password)

**Key Alias**: A name for your signing key (e.g., `upload`, `release`, `myappkey`)

**Certificate Information (these identify your organization):**
- **CN (Common Name)**: Your app name or organization (e.g., `MyApp`, `My Company`)
- **OU (Organizational Unit)**: Your department (e.g., `Mobile Development`, `Engineering`)
- **O (Organization)**: Your company name (e.g., `MyCompany Inc`)
- **L (Locality)**: Your city (e.g., `Tucupita`)
- **ST (State)**: Your state/province (e.g., `Delta Amacuro`)
- **C (Country)**: Your country code (e.g., `VE`, `CO`, `BR`)

#### Create the Keystore File

```bash
# Navigate to your Android app directory
cd android/app

# Create the keystore (replace ALL values with your choices from above)
keytool -genkey \
    -v \
    -keystore upload-keystore.jks \
    -keyalg RSA \
    -keysize 2048 \
    -validity 10000 \
    -alias YOUR_CHOSEN_ALIAS \
    -storetype JKS \
    -storepass YOUR_CHOSEN_STORE_PASSWORD \
    -keypass YOUR_CHOSEN_KEY_PASSWORD \
    -dname "CN=YOUR_APP_NAME, OU=YOUR_DEPARTMENT, O=YOUR_COMPANY, L=YOUR_CITY, ST=YOUR_STATE, C=YOUR_COUNTRY"
```

**Command Explanation:**
- `-keystore upload-keystore.jks`: Creates file named `upload-keystore.jks`
- `-keyalg RSA -keysize 2048`: Uses RSA encryption with 2048-bit key (secure)
- `-validity 10000`: Certificate valid for ~27 years
- `-alias YOUR_CHOSEN_ALIAS`: Replace with your chosen alias name
- `-storepass / -keypass`: Replace with your chosen passwords
- `-dname`: Replace with your organization information

**Example with real values:**
```bash
# Example - replace with YOUR actual values
keytool -genkey \
    -v \
    -keystore upload-keystore.jks \
    -keyalg RSA \
    -keysize 2048 \
    -validity 10000 \
    -alias myapprelease \
    -storetype JKS \
    -storepass MySecurePassword123 \
    -keypass MySecurePassword123 \
    -dname "CN=My Mobile App, OU=Development, O=My Company, L=Tucupita, ST=Delta Amacuro, C=VE"
```

#### Record Your Credentials

**CRITICAL**: Immediately write down these values - you'll need them forever:

```
Keystore File: android/app/upload-keystore.jks
Store Password: [the password you chose]
Key Password: [the key password you chose]  
Key Alias: [the alias you chose]
```

**Store this information securely:**
- Add to your password manager
- Store in an encrypted vault (e.g., Bitwarden, 1Password, KeePass, gopass)
- Maintain an offline encrypted backup (e.g., VeraCrypt/LUKS) in a separate location
- **Never lose these values** - you cannot recover them!

#### Verify Keystore Creation

Test that your new keystore works:

```bash
# Test the keystore (use YOUR actual values)
keytool -list -v -keystore upload-keystore.jks -alias YOUR_ALIAS -storepass YOUR_STORE_PASSWORD
```

You should see output showing your certificate information. If you get errors, the keystore wasn't created correctly.

### Create/Update key.properties

Now create a `key.properties` file with your keystore information:

**Navigate to android directory:**
```bash
cd android
```

**Create/edit key.properties:**
```bash
# Create or edit the file
nano key.properties
# Or use your preferred text editor: code key.properties, vim key.properties, etc.
```

**Add your keystore information:**

**If you just created a keystore above, use the values you chose:**
```properties
storePassword=MySecurePassword123
keyPassword=MySecurePassword123
keyAlias=myapprelease
storeFile=upload-keystore.jks
```

**If you have an existing keystore, use its actual credentials:**
```properties
storePassword=YOUR_EXISTING_STORE_PASSWORD
keyPassword=YOUR_EXISTING_KEY_PASSWORD
keyAlias=YOUR_EXISTING_KEY_ALIAS
storeFile=upload-keystore.jks
```

**File explanation:**
- `storePassword`: The password that protects your keystore file
- `keyPassword`: The password that protects your signing key (often same as store password)
- `keyAlias`: The name of your signing key within the keystore
- `storeFile`: The filename of your keystore (should match the file you have/created)

**Save and close the file.** You now have a complete keystore setup!

## Step 1: Verify Your Local Setup

This step ensures your keystore and credentials work before setting up GitHub.

### Test Your Keystore

Navigate to your Android directory and test your keystore:

```bash
# Navigate to android directory
cd android

# Test your keystore (replace with YOUR actual values from key.properties)
keytool -list -v -keystore app/upload-keystore.jks -alias YOUR_KEY_ALIAS -storepass YOUR_STORE_PASSWORD
```

**Replace the placeholders:**
- `YOUR_KEY_ALIAS`: Use the value from your `key.properties` file
- `YOUR_STORE_PASSWORD`: Use the value from your `key.properties` file

### Expected Success Output

If successful, you'll see something like:
```
Alias name: youraliasname
Creation date: Aug 13, 2025
Entry type: PrivateKeyEntry
Certificate chain length: 1
Certificate[1]:
Owner: CN=Your App Name, OU=Organization, O=Company...
Valid from: Wed Aug 13 18:47:47 UYT 2025 until: Sun Dec 29 18:47:47 UYT 2052
Certificate fingerprints:
     SHA1: FD:DB:64:E4:7C:60:4D:BD:27:9F:A7:C2:D7:16:AB:6B:40:74:9A:F3
     SHA256: 67:6F:67:26:76:D3:59:3A:C5:2F:01:7C:58:1C:50:C0:8B...
```

**🎉 Success!** Save these SHA1 and SHA256 fingerprints - you'll need them to verify GitHub builds use the same certificate.

### Common Errors and Solutions

#### ❌ "keystore password was incorrect"
Your store password is wrong. Check these:
1. **Verify the password in key.properties** - make sure there are no extra spaces or typos
2. **Try common passwords**: `android`, `123456`, `password`, your app name
3. **Check your notes/password manager** for the correct password

#### ❌ "Alias does not exist"
Your alias name is wrong. Fix this:
1. **List all aliases in your keystore**:
   ```bash
   keytool -list -keystore app/upload-keystore.jks -storepass YOUR_STORE_PASSWORD
   ```
2. **Try common aliases**: `upload`, `key0`, `release`, `androiddebugkey`
3. **Update your key.properties** with the correct alias

#### ❌ "Keystore file not found"
The file path is wrong:
1. **Check the file exists**: `ls -la app/upload-keystore.jks`
2. **Look for keystore files**: `find . -name "*.jks" -o -name "*.keystore"`
3. **Update the storeFile path** in key.properties

### Test Local Build

Once the keystore test succeeds, verify your local Flutter build works:

```bash
# Navigate to your project root
cd ..

# Build a release APK
flutter build apk --release
```

This should complete successfully and create `build/app/outputs/flutter-apk/app-release.apk`.

## Step 2: Extract Values for GitHub Secrets

Now that your local setup works, extract the exact values for GitHub Secrets.

### Record Your Verified Values

From your working `key.properties` file, note these values:

**Open your key.properties file:**
```bash
cat android/key.properties
```

**Record these 4 values** (you'll need them for GitHub):
1. **Store Password**: `storePassword=` value
2. **Key Password**: `keyPassword=` value  
3. **Key Alias**: `keyAlias=` value
4. **Store File**: `storeFile=` value (usually `upload-keystore.jks`)

### Generate Base64 Keystore

Convert your keystore file to base64 for secure storage in GitHub:

```bash
# Navigate to your project directory
cd /path/to/your/flutter/project

# Generate base64 (one very long line; choose your platform)
# Linux (GNU coreutils):
base64 -w 0 android/app/upload-keystore.jks
# macOS (BSD base64):
base64 -b 0 android/app/upload-keystore.jks
# Portable (OpenSSL, works everywhere):
openssl base64 -A -in android/app/upload-keystore.jks
```

**Copy the entire output** - it will be thousands of characters long. Save it temporarily in a text file.

### Verify Base64 Conversion

Test that your base64 conversion works:

```bash
# Save your base64 string to test (replace with your actual long string)
BASE64_STRING="your_very_long_base64_string_here"

# Test decoding (choose your platform)
# Linux (GNU coreutils):
echo "$BASE64_STRING" | base64 -d > test-keystore.jks
# macOS (BSD base64):
echo "$BASE64_STRING" | base64 -D > test-keystore.jks
# Portable (OpenSSL):
echo "$BASE64_STRING" | openssl base64 -d -A > test-keystore.jks

# Verify it works with your credentials
keytool -list -v -keystore test-keystore.jks -alias YOUR_ALIAS -storepass YOUR_STORE_PASSWORD

# Clean up
rm test-keystore.jks
```

If the verification fails, regenerate the base64 string.

## Step 3: Add Secrets to GitHub Repository

### Navigate to GitHub Secrets

1. Go to your GitHub repository on github.com
2. Click the **Settings** tab (you need admin access)
3. In the left sidebar, click **Secrets and variables**
4. Click **Actions**

### Add the 4 Required Secrets

Add each secret by clicking **New repository secret**:

#### 1. ANDROID_KEYSTORE_FILE
- **Name**: `ANDROID_KEYSTORE_FILE`
- **Value**: Your very long base64 string from Step 2

#### 2. ANDROID_KEYSTORE_PASSWORD
- **Name**: `ANDROID_KEYSTORE_PASSWORD`
- **Value**: The `storePassword` value from your key.properties

#### 3. ANDROID_KEY_PASSWORD
- **Name**: `ANDROID_KEY_PASSWORD`  
- **Value**: The `keyPassword` value from your key.properties

#### 4. ANDROID_KEY_ALIAS
- **Name**: `ANDROID_KEY_ALIAS`
- **Value**: The `keyAlias` value from your key.properties

### Verify Secrets Added

After adding all 4 secrets, you should see them listed in your repository secrets. The values will be hidden for security, but you can see the names.

## Step 4: Test GitHub Actions Build

### Trigger a Test Build

Make a small change to trigger your workflow:

1. **Update your app version** in `pubspec.yaml` (increase the version number)
2. **Commit and push** to your main branch
3. **Monitor the GitHub Actions tab** in your repository

### Monitor the Build

Watch for these steps in your GitHub Actions log:

#### ✅ Setup Android Keystore
Should show:
```
Setting environment variables
ANDROID_KEYSTORE_PASSWORD=***
ANDROID_KEY_PASSWORD=***
ANDROID_KEY_ALIAS=***
ANDROID_KEYSTORE_FILE=upload-keystore.jks
```

#### ✅ Build APK
Should complete without errors about keystore or signing.

#### ✅ Verify APK Signing  
Should show:
```
✅ APK built successfully
Verifying with jarsigner...
jar verified.
✅ Certificate details displayed
```

### Strong APK Signature Verification

The build process now uses comprehensive signature verification beyond just checking for META-INF presence (which can exist in debug builds). Here's how to verify signatures manually and understand the automated checks:

#### Manual Signature Verification

##### Step 1: Verify signature integrity with jarsigner

```bash
# Navigate to your project root
cd /path/to/your/flutter/project

# Verify APK signature (exits non-zero if signature invalid)
jarsigner -verify -verbose -certs build/app/outputs/flutter-apk/app-release.apk

# For detailed certificate information
jarsigner -verify -verbose -certs -strict build/app/outputs/flutter-apk/app-release.apk
```

Note: jarsigner validates only V1 (JAR) signatures. Many Android builds use V2/V3/V4. Prefer apksigner for full Android signature verification when available.

**Expected output for valid signature:**
```
jar verified.
Certificate details displayed...
```

##### Step 2: Verification with apksigner (preferred, if available)

```bash
# Find apksigner in your Android SDK build-tools
find $ANDROID_HOME/build-tools -name apksigner -type f | sort -V | tail -1

# Verify with apksigner
apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk

# Verbose verification
apksigner verify --verbose build/app/outputs/flutter-apk/app-release.apk
```

#### Certificate Fingerprint Verification

##### Extract keystore certificate SHA-256 fingerprint:
```bash
keytool -list -v -keystore android/app/upload-keystore.jks -alias YOUR_ALIAS -storepass YOUR_STORE_PASSWORD | grep "SHA256:"
```

##### Extract APK certificate fingerprint:
```bash
# Method 1: Using jarsigner
jarsigner -verify -verbose -certs build/app/outputs/flutter-apk/app-release.apk | grep "SHA256:"

# Method 2: Using apksigner (if available)
apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk 2>&1 | grep 'SHA-256'
```

##### Compare and verify:
- Both keystore and APK should show identical SHA-256 fingerprints
- This ensures the APK is signed with your expected certificate
- Prevents signing with wrong certificates or debug keys

#### Automated CI Verification

The GitHub Actions workflow performs these verification steps automatically:

1. **Signature validation**: Uses `jarsigner -verify -verbose -certs` to validate signature integrity
2. **Certificate display**: Shows certificate details in build logs for verification
3. **apksigner fallback**: Uses `apksigner verify --print-certs` when build-tools are available
4. **Build failure**: Non-zero exit codes from verification tools fail the build

**What the CI checks prevent:**
- Unsigned APKs reaching production
- APKs signed with debug certificates
- APKs signed with wrong/compromised certificates
- Signature corruption during build process

#### Troubleshooting Signature Issues

**"jar verified." not shown**: APK signature is invalid or corrupted
- Check that keystore file exists and is not corrupted
- Verify all signing credentials (passwords, alias) are correct
- Ensure Flutter build completed successfully

**Fingerprint mismatch**: APK signed with different certificate
- Check that correct keystore file is being used
- Verify keystore alias matches your configuration
- Ensure no debug/temporary certificates are being used

**"Certificate fingerprints" not found**: Keystore or APK access issues
- Verify keystore file path and permissions
- Check that keystore password and alias are correct
- Ensure APK file exists and is not corrupted

## Step 5: Local Development Setup

For continued local development, keep your working `key.properties` file:

```properties
# Keep these exact values that worked in Step 1
storePassword=your_working_store_password
keyPassword=your_working_key_password
keyAlias=your_working_alias
storeFile=upload-keystore.jks
```

The build system will:
- Use your keystore when available locally
- Fall back to debug signing if keystore is missing
- Show warnings about which signing method is being used

## Troubleshooting

### GitHub Actions Build Failures

#### ❌ "keystore not found" in GitHub Actions
**Cause**: Base64 keystore secret is wrong or missing
**Solution**: 
1. Regenerate base64: `base64 -w 0 android/app/upload-keystore.jks`
2. Update `ANDROID_KEYSTORE_FILE` secret with new string

#### ❌ "Wrong password" in GitHub Actions  
**Cause**: Password secrets don't match your keystore
**Solution**:
1. Double-check the values in your local `key.properties`
2. Update GitHub secrets with exact same values
3. Ensure no extra spaces or characters

#### ❌ "APK appears to be signed" fails
**Cause**: APK wasn't properly signed 
**Solution**:
1. Check that keystore file was created in "Setup Android Keystore" step
2. Verify all 4 secrets are present and correct

### Local Build Issues

#### ❌ Local builds fail after GitHub setup
**Cause**: `key.properties` file was changed
**Solution**: Restore your working `key.properties` with the values from Step 1

### Certificate Mismatch

#### ❌ Different fingerprints between local and GitHub
**Cause**: GitHub is using different keystore or credentials
**Solution**:
1. Verify base64 keystore decodes to identical file
2. Check all GitHub secrets match your local `key.properties`
3. Regenerate all secrets if needed

## Security Best Practices

### 🔐 Keep Credentials Secure
- Never commit `key.properties` or keystore files to your repository
- Use GitHub Secrets for all sensitive values
- Regularly audit who has access to repository secrets
- Enable 2FA on your GitHub account

### 🛡️ Backup Your Keystore
- Keep secure backups of your keystore file
- Document your passwords in a password manager
- Test your backups periodically

### ⚠️ If Compromised
If you suspect your keystore or passwords are compromised:
1. Immediately change GitHub secrets
2. Generate new keystore for future releases
3. Review GitHub Actions history for unauthorized builds
4. If you use Google Play App Signing, rotate the upload key via Play Console and reconfigure CI with the new upload key. Document the new fingerprints.