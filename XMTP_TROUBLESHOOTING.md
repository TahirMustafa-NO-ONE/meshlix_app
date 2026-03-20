# Fixing "Address is not on XMTP network yet" Error

## Problem
You're seeing this error because accounts created **before** XMTP implementation don't have XMTP identities yet. Even after logging out and back in, the XMTP identity might not have been created properly.

## Solution 1: Complete App Data Reset (Recommended)

### For Android:
```bash
# Clear all app data
adb shell pm clear com.yourpackage.meshlix_app

# Or manually:
# Settings → Apps → Meshlix → Storage → Clear Data
```

### For iOS:
```bash
# Delete and reinstall the app
```

### Then:
1. Login with your account
2. Wait **30 seconds** after login before trying to send message
3. Check logs to verify XMTP identity was created

## Solution 2: Manual XMTP Reinitialization (Quick Fix)

If you don't want to clear data, follow these steps:

### Step 1: Check Current Status

Run this command while app is running:
```bash
flutter logs | grep -E "XmtpService|XmtpKeyStorage"
```

Look for these lines:
- ✅ **Good**: `[XmtpService] XMTP client initialized successfully`
- ✅ **Good**: `[XmtpKeyStorage] Saving keys for wallet: 0x...`
- ❌ **Bad**: `[XmtpService] Failed to initialize XMTP client`

### Step 2: Force Logout and Re-login

**On BOTH devices (Alice and Bob):**

1. Go to Profile tab
2. Tap logout button
3. **Wait 5 seconds**
4. Login again
5. **Wait 30-60 seconds** after login (let XMTP initialize)
6. Check logs:

```bash
flutter logs | grep "Creating new XMTP identity"
```

You should see:
```
[XmtpService] Creating new XMTP identity...
[XmtpService] Client created from wallet and keys saved
[XmptKeyStorage] Saving keys for wallet: 0x...
```

### Step 3: Verify Both Users Are on XMTP

**On Device 1 (Alice):**
1. Go to Home tab
2. Try to start chat with Bob's address
3. If error still appears, Bob's XMTP identity isn't ready yet

**On Device 2 (Bob):**
1. Check logs again
2. Make sure you see "XMTP client initialized successfully"

### Step 4: Try Messaging Again

Wait 30 seconds after both users show "initialized successfully", then try messaging.

## Solution 3: Check XMTP Network Settings

Make sure both users are on the **same XMTP network**:

Check your `.env` file:
```bash
WEB3AUTH_CLIENT_ID=your_client_id
WEB3AUTH_NETWORK=sapphire_devnet  # ← Make sure this is consistent
```

Both devices **MUST** use `sapphire_devnet` for testing.

## Solution 4: Delete XMTP Keys Manually

If issue persists, delete stored XMTP keys to force regeneration:

### Android:
```bash
# Clear secure storage (where XMTP keys are stored)
adb shell run-as com.yourpackage.meshlix_app rm -rf /data/data/com.yourpackage.meshlix_app/files/flutter_secure_storage
```

### Then:
1. Restart app
2. Login again
3. New XMTP identity will be created

## Diagnostic Steps

### Check if XMTP is initialized:

Add this debug check in your app. Open Profile screen and check logs:

```bash
flutter logs
```

You should see:
```
[AppInitService] Initializing services for wallet: 0x...
[DbService] Opening user database...
[XmtpService] Initializing XMTP client...
[XmtpService] Network: dev.xmtp.network
[XmtpService] Wallet: 0x...
[XmtpService] Loading from stored keys...  ← Second login
   OR
[XmtpService] Creating new XMTP identity...  ← First login
[XmtpService] XMTP client initialized successfully
[XmtpService] Wallet address: 0x...
```

### If you see errors:

#### Error: "No private key found"
- Login again
- Check `.env` has correct Web3Auth credentials

#### Error: "Failed to initialize XMTP client"
- Check internet connection
- Verify XMTP network is reachable
- Try using production network instead of dev

#### Timeout or hanging:
- XMTP server might be down
- Try again in a few minutes
- Check https://status.xmtp.com

## Testing Procedure (Proper Way)

To properly test with existing accounts:

### Device 1 (Alice):
1. **Clear app data completely**
2. Launch app
3. Login with Alice's account
4. **Wait 60 seconds** (watch logs for "XMTP client initialized successfully")
5. Go to Profile and copy Alice's wallet address
6. **Wait another 30 seconds**

### Device 2 (Bob):
1. **Clear app data completely**
2. Launch app
3. Login with Bob's account
4. **Wait 60 seconds** (watch logs for "XMTP client initialized successfully")
5. Go to Profile and copy Bob's wallet address
6. **Wait another 30 seconds**

### Now Test Messaging:
1. On Device 1 (Alice), go to Home
2. Paste Bob's wallet address
3. Tap "Send Chat Request"
4. Should now open chat screen ✅

### Send First Message:
1. Alice types "Hello Bob!"
2. Tap send
3. Wait 5-10 seconds
4. On Device 2 (Bob), check Chats tab
5. Should see message from Alice ✅

## Why This Happens

When you login for the **first time** after XMTP implementation:

1. ✅ Auth completes (Web3Auth)
2. ✅ Wallet address generated
3. ⏳ XMTP identity creation starts (5-10 seconds)
4. ❌ If you try to message immediately, recipient isn't "on XMTP network" yet

**The 30-60 second wait is CRITICAL** for first-time XMTP setup.

## Quick Verification Command

Run this to verify XMTP initialization:

```bash
flutter logs --since=1m | grep -A 5 "Initializing XMTP"
```

Expected output:
```
[XmtpService] Initializing XMTP client...
[XmtpService] Network: dev.xmtp.network
[XmtpService] Wallet: 0x...
[XmtpService] Creating new XMTP identity...
[XmtpService] Client created from wallet and keys saved
[XmtpService] XMTP client initialized successfully
```

## Still Not Working?

If you still see the error after all these steps:

1. **Both users MUST clear app data completely**
2. **Both users MUST login fresh**
3. **Both users MUST wait 60 seconds after login**
4. Check logs on both devices for "XMTP client initialized successfully"
5. Make sure both using same XMTP network (dev or prod)
6. Try restarting the app
7. Check internet connection on both devices

## Alternate Test

If you want to test quickly without a second device:

1. Use https://xmtp.chat in a browser
2. Connect wallet
3. Send message from your app to that wallet address
4. Check if message appears in browser

This verifies your app's XMTP integration is working.
