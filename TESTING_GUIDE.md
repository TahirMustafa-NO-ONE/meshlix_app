# Complete Guide: Testing & Using Meshlix P2P Chat App

## Prerequisites

### 1. Environment Setup
Before running the app, ensure you have a `.env` file with your Web3Auth credentials:

```bash
# .env file in project root
WEB3AUTH_CLIENT_ID=your_web3auth_client_id_here
WEB3AUTH_NETWORK=sapphire_devnet
```

**Get Web3Auth Client ID:**
1. Go to https://dashboard.web3auth.io
2. Create an account/login
3. Create a new project
4. Copy your Client ID
5. Use `sapphire_devnet` for testing

### 2. Install Dependencies
```bash
flutter pub get
flutter pub run build_runner build
```

## Running the App

### For Android
```bash
flutter run
```

### For iOS
```bash
cd ios && pod install && cd ..
flutter run
```

### For Testing (Two Devices Required)
You need **TWO devices/emulators** to test P2P messaging:
- Device 1: Alice (sender)
- Device 2: Bob (receiver)

## Testing Flow

### Phase 1: Initial Setup & Authentication

#### Test 1.1: First Launch
**Device 1 (Alice):**
1. Launch app
2. Should see splash screen with "MESHLIX" branding
3. Should auto-navigate to Auth Screen (no session exists)

**Expected:**
- Splash screen appears for ~1.5 seconds
- "Checking session..." status text
- Redirects to Auth Screen

#### Test 1.2: Google Sign-In
**Device 1 (Alice):**
1. Tap "Continue with Google"
2. Complete Google authentication in browser
3. App should initialize services and navigate to home

**Expected:**
- Google OAuth flow opens
- After authentication, returns to app
- Status shows "Initializing services..."
- Navigates to Home screen with bottom navigation

**Log Output to Check:**
```
[AuthService] Client ID: BPe...
[AppInitService] Initializing services for wallet: 0x...
[DbService] Opening user database...
[XmtpService] Initializing XMTP client...
[SyncService] Starting initial sync...
```

#### Test 1.3: Alternative - Email Sign-In
**Device 2 (Bob):**
1. Enter email address
2. Tap "CONTINUE WITH EMAIL"
3. Check email for magic link/OTP
4. Complete authentication

### Phase 2: XMTP Identity Creation

**Device 1 (Alice) - First Time User:**
1. After login, XMTP creates identity keys
2. Wait 5-10 seconds for identity creation
3. Check logs for confirmation

**Expected Log Output:**
```
[XmtpService] Creating new XMTP identity...
[XmtpService] Client created from wallet and keys saved
[XmtpKeyStorage] Saving keys for wallet: 0x...
```

**Device 2 (Bob):**
- Repeat same process
- Bob's identity is created separately

### Phase 3: Navigation & UI Testing

#### Test 3.1: Bottom Navigation
**Any Device:**
1. Verify 4 tabs exist:
   - 🏠 Home
   - 💬 Chats
   - 👥 Contacts
   - 👤 Profile

2. Tap each tab and verify screens load

**Expected:**
- All tabs navigate correctly
- No crashes or errors

#### Test 3.2: Profile Screen
**Any Device:**
1. Go to Profile tab
2. Verify information displayed:
   - Profile picture/avatar
   - User name
   - Wallet address (clickable to copy)
   - Private key section (hidden by default)

3. Test Private Key:
   - Tap "Show" to reveal
   - Tap "Copy" to copy to clipboard
   - Verify warning message displayed

4. Test Copy Wallet Address:
   - Tap copy icon next to wallet address
   - Should show "Address copied to clipboard"

### Phase 4: Core Messaging Feature

#### Test 4.1: Start New Chat from Home
**Device 1 (Alice) needs Device 2 (Bob)'s wallet address:**

1. **Get Bob's Address:**
   - On Device 2 (Bob), go to Profile
   - Copy wallet address (0x...)

2. **Alice Starts Chat:**
   - On Device 1, go to Home tab
   - Paste Bob's address in input field
   - Tap "Send Chat Request"

**Expected:**
- If Bob's address **IS** on XMTP: Opens chat screen
- If address **NOT** on XMTP: Orange message "Address is not on XMTP network yet"
- Invalid address format: Shows error "Please enter a valid Ethereum address (0x...)"

**Log Output:**
```
[ChatController] Error creating conversation: ...
[XmtpService] Sending message to: 0x...
[XmtpService] Message sent successfully
```

#### Test 4.2: Send First Message
**Device 1 (Alice):**
1. After chat screen opens
2. Type message in input at bottom
3. Tap send button

**Expected:**
- Message appears immediately in chat (optimistic UI)
- Message shows pending status (⏱️ clock icon)
- After sync, shows double check (✓✓) for sent

**Log Output:**
```
[SyncService] Sending message to: 0x...
[DbService] Message saved: 1234567890
[SyncService] Message sent and synced
```

#### Test 4.3: Receive Message (Real-Time)
**Device 2 (Bob):**
1. Wait a few seconds after Alice sends message
2. Check Chats tab - should see new conversation
3. Unread badge should show "1"
4. Tap conversation to open

**Expected:**
- Conversation appears in Chats list
- Unread count badge visible on Chats tab icon
- Last message preview shown
- Opening chat marks as read (badge disappears)

**Log Output on Bob's device:**
```
[XmtpService] New message received
[XmtpService] From: 0x...
[XmtpService] Content: Hello!
[SyncService] Processing incoming message: ...
[DbService] Message saved: ...
```

#### Test 4.4: Reply to Message
**Device 2 (Bob):**
1. In open chat with Alice
2. Type reply message
3. Send

**Device 1 (Alice):**
- Should receive Bob's message in real-time
- Message appears in chat
- Notification badge on Chats tab updates

### Phase 5: Advanced Features

#### Test 5.1: Multiple Conversations
**Device 1 (Alice):**
1. Get a third wallet address (Device 3 or test address)
2. Start new chat from Home
3. Send message

**Expected:**
- Two conversations now in Chats list
- Sorted by most recent message
- Each shows correct last message and timestamp

#### Test 5.2: Contacts Screen
**Any Device:**
1. Go to Contacts tab
2. Should see all addresses you've chatted with

**Expected:**
- Alice sees Bob as contact
- Bob sees Alice as contact
- Tap contact to open chat

#### Test 5.3: Pull-to-Refresh
**Any Device:**
1. Go to Chats screen
2. Pull down from top
3. Wait for refresh animation

**Expected:**
- Refresh indicator appears
- Conversations reload from database
- Any new messages appear

#### Test 5.4: Chat Screen Features
Test these in any open chat:

1. **Date Headers:**
   - Send messages on different days
   - Should see "Today", "Yesterday", date headers

2. **Message Status Icons:**
   - Your messages show status:
     - ⏱️ = Pending
     - ✓ = Sending
     - ✓✓ = Sent and synced
     - ❌ = Failed

3. **Scroll Behavior:**
   - Send many messages
   - New messages auto-scroll to bottom
   - Can manually scroll up to read history

4. **Refresh Chat:**
   - Tap refresh icon in chat header
   - Reloads messages from database

### Phase 6: Offline/Online Behavior

#### Test 6.1: Offline Sending
**Device 1:**
1. Turn on Airplane mode
2. Try to send message

**Expected:**
- Message saves to local database
- Shows pending status (⏱️)
- Message appears in chat but not sent to XMTP

**Log Output:**
```
[SyncService] Failed to send message, kept as pending: ...
[DbService] Message saved with status: pending
```

#### Test 6.2: Online Sync
**Device 1:**
1. Turn off Airplane mode
2. Wait a few seconds

**Expected:**
- Pending messages automatically retry
- Status updates to sent (✓✓)
- Recipient receives messages

**Log Output:**
```
[SyncService] Retrying pending messages...
[SyncService] Found 1 pending messages
[SyncService] Pending message sent: ...
```

### Phase 7: Session Persistence

#### Test 7.1: Close & Reopen App
**Any Device:**
1. Close app completely (swipe away from recent apps)
2. Reopen app

**Expected:**
- Splash screen appears
- Shows "Checking session..."
- Then "Initializing services..."
- Auto-navigates to Home (logged in)
- All messages still visible

**Log Output:**
```
[SplashScreen] Valid session found, user authenticated
[AppInitService] Initializing services for wallet: 0x...
[DbService] Database already open for wallet: ...
```

#### Test 7.2: Logout & Login
**Any Device:**
1. Go to Profile tab
2. Tap logout icon (top right)
3. Should return to Auth screen
4. Login again with same account

**Expected:**
- Clean logout (no errors)
- Returns to Auth screen
- After login, all previous messages restored
- Conversations and contacts intact

**Log Output:**
```
[AppInitService] Disposing services...
[SyncService] Real-time sync stopped
[DbService] Database closed
[AuthService] Logged out successfully
```

### Phase 8: Error Scenarios

#### Test 8.1: Invalid Address
**Any Device:**
1. Go to Home
2. Enter invalid addresses:
   - "hello" → Error: not a valid address
   - "0x123" → Error: address too short
   - "random text" → Error: must start with 0x

#### Test 8.2: Network Errors
Simulate by using slow/unstable network:
- Messages should save locally first
- Retry mechanism should work
- User sees appropriate status indicators

### Phase 9: Multi-User Testing

#### Test 9.1: Same Device, Different Accounts
**Single Device:**
1. Login as Alice
2. Send some messages
3. Logout
4. Login as Bob (different account)

**Expected:**
- Bob sees ONLY his conversations
- Alice's messages NOT visible to Bob
- Each user has isolated database

**Database Structure Check:**
```
Hive boxes created:
- messages_0xalice...
- conversations_0xalice...
- contacts_0xalice...
- messages_0xbob...
- conversations_0xbob...
- contacts_0xbob...
```

## Troubleshooting

### Issue: XMTP Initialization Fails
**Symptom:** Error during service initialization

**Solutions:**
1. Check internet connection
2. Verify using dev network: `dev.xmtp.network`
3. Check logs for specific error:
```bash
flutter logs | grep XmtpService
```

### Issue: Messages Not Syncing
**Symptom:** Sent messages stuck in pending

**Solutions:**
1. Check if both users on same XMTP network (dev/prod)
2. Pull to refresh in Chats screen
3. Check logs:
```bash
flutter logs | grep SyncService
```

### Issue: "Address not on XMTP network"
**Symptom:** Can't start chat with address

**Solutions:**
1. Recipient must login to app first (creates XMTP identity)
2. Wait 30 seconds after recipient's first login
3. Try again

### Issue: Database Errors
**Symptom:** App crashes when opening database

**Solutions:**
1. Clear app data
2. Rebuild adapters:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### Issue: Multiple Devices Same Account
**Symptom:** Messages not syncing between devices

**Expected Behavior:**
- XMTP identity tied to wallet address
- Both devices should sync via XMTP network
- May take a few seconds for messages to appear

## Performance Expectations

### First Launch (Cold Start)
- Auth: 2-3 seconds
- XMTP Identity Creation: 5-10 seconds (first time only)
- Database Setup: <1 second

### Subsequent Launches (Warm Start)
- Session Check: <1 second
- XMTP Init: 1-2 seconds (loads from cached keys)
- Database Open: <1 second
- Initial Sync: 2-5 seconds (depends on message history)

### Message Delivery Times
- Send: 1-3 seconds
- Receive: 2-5 seconds (real-time via stream)
- Offline Messages: Sync on next connection

## Debug Commands

### Check Service Status
```bash
# View all logs
flutter logs

# Filter by service
flutter logs | grep -E "XmtpService|DbService|SyncService|ChatController"

# Check database files (Android)
adb shell run-as com.yourpackage ls /data/data/com.yourpackage/app_flutter/
```

### Reset Everything
```bash
# Clear app data (Android)
adb shell pm clear com.yourpackage

# Clear app data (iOS)
# Delete and reinstall app
```

## Testing Checklist

- [ ] **Authentication**
  - [ ] Google login works
  - [ ] Email OTP login works
  - [ ] Session persists after restart
  - [ ] Logout clears session

- [ ] **XMTP Integration**
  - [ ] Identity created on first login
  - [ ] Keys stored securely
  - [ ] Can send messages
  - [ ] Can receive messages real-time
  - [ ] Messages sent to correct address

- [ ] **Database**
  - [ ] User-scoped data isolation works
  - [ ] Messages persist after app restart
  - [ ] Switching accounts isolates data
  - [ ] Pull-to-refresh works

- [ ] **UI/UX**
  - [ ] All 4 tabs navigate correctly
  - [ ] Chat list shows conversations
  - [ ] Chat screen displays messages
  - [ ] Contacts screen shows contacts
  - [ ] Profile shows user info
  - [ ] Unread badges work

- [ ] **Offline Mode**
  - [ ] Messages queue when offline
  - [ ] Auto-retry when online
  - [ ] Status indicators update

- [ ] **Error Handling**
  - [ ] Invalid addresses rejected
  - [ ] Network errors handled gracefully
  - [ ] Empty states shown properly

## Success Criteria

✅ **App is working correctly if:**
1. Both users can login successfully
2. Alice can send message to Bob
3. Bob receives message within 5 seconds
4. Messages persist after app restart
5. Offline messages sync when online
6. Multiple conversations work independently
7. No crashes or data loss

🎉 **Congratulations!** Your P2P chat app is fully functional!

## Additional Notes

### Architecture Overview
```
┌─────────────────────────────────────────────┐
│           User Interface (Flutter)          │
│  (Home, Chats, Contacts, Profile Screens)   │
└─────────────────┬───────────────────────────┘
                  │
┌─────────────────▼───────────────────────────┐
│          ChatController (State)             │
│     (Manages conversations & messages)      │
└─────────────────┬───────────────────────────┘
                  │
        ┌─────────┴─────────┐
        │                   │
┌───────▼────────┐  ┌──────▼──────────┐
│  SyncService   │  │  DbService      │
│  (XMTP sync)   │  │  (Hive cache)   │
└───────┬────────┘  └─────────────────┘
        │
┌───────▼────────┐
│  XmtpService   │
│  (Transport)   │
└────────────────┘
```

### Key Files Reference

| Component | Location |
|-----------|----------|
| App Entry | `lib/main.dart` |
| Auth Screen | `lib/screens/auth/auth_screen.dart` |
| Home Screen | `lib/screens/home/home_screen.dart` |
| Chat List | `lib/screens/chat/chat_list_screen.dart` |
| Chat Screen | `lib/screens/chat/chat_screen.dart` |
| Contacts | `lib/screens/contacts/contacts_screen.dart` |
| Profile | `lib/screens/home/profile_screen.dart` |
| Navigation | `lib/screens/home/main_navigation_screen.dart` |
| Chat Controller | `lib/controllers/chat_controller.dart` |
| XMTP Service | `lib/services/xmtp/xmtp_service.dart` |
| DB Service | `lib/db/db_service.dart` |
| Sync Service | `lib/services/sync/sync_service.dart` |
| App Init | `lib/services/app_init_service.dart` |

### Environment Variables
Make sure your `.env` file is properly configured:
```bash
WEB3AUTH_CLIENT_ID=BPe...  # From dashboard.web3auth.io
WEB3AUTH_NETWORK=sapphire_devnet  # or sapphire_mainnet
```

### Common Error Messages

| Error | Meaning | Solution |
|-------|---------|----------|
| "No wallet address found" | User not authenticated | Login first |
| "XMTP client not initialized" | Service initialization failed | Check internet, restart app |
| "Address is not on XMTP network yet" | Recipient hasn't logged in | Recipient must login once |
| "Database not initialized" | DB not opened | Should auto-initialize, restart if persists |
| "Message already exists" | Duplicate message ID | Normal deduplication, ignore |

### Best Practices for Testing

1. **Always test with 2 devices** - P2P requires both sender and receiver
2. **Check logs** - Most issues are visible in Flutter logs
3. **Wait for syncing** - Give 5-10 seconds for first-time setup
4. **Test offline mode** - Verify messages queue and retry
5. **Test session persistence** - Close and reopen app frequently
6. **Clear data between major tests** - Start fresh for accurate results
7. **Use dev network** - Faster and free for testing

---

**Last Updated:** 2026-03-20
**App Version:** 1.0.0
**XMTP SDK Version:** 1.0.0
**Flutter Version:** 3.x+
