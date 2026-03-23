# Meshlix Flutter App

Meshlix is a Flutter-based decentralized chat client for XMTP. The app uses Web3Auth for onboarding, stores wallet-sensitive data locally on-device, syncs conversations through a lightweight Node.js backend bridge, and keeps chat state available with an offline-first local database.

## Overview

The Flutter app is responsible for:

- authenticating users with Web3Auth
- deriving and persisting the user's wallet identity
- storing conversations, contacts, and messages locally with Hive
- connecting to the Meshlix XMTP backend over HTTP and WebSocket
- syncing conversations in real time
- supporting per-wallet local data isolation on the same device

## Core Features

- Google sign-in via Web3Auth
- Passwordless email sign-in via Web3Auth
- Persistent session restore on app relaunch
- Secure private key storage with `flutter_secure_storage`
- Per-user local databases with Hive
- Real-time message delivery through WebSocket updates
- Offline-first local message creation and retry flow
- Contact list built from conversation history
- Message request / consent handling
- Profile screen with wallet address and locally stored key visibility controls

## Current Status

Implemented and working in the app codebase:

- splash-based session restoration
- authenticated app initialization
- backend session bootstrap
- initial conversation sync
- real-time message updates
- unread count handling
- message request approval / decline
- offline pending-message retry

Not fully implemented yet:

- external wallet connection from the auth screen currently throws a "coming soon" exception
- the default Android and iOS bundle identifiers are still example values
- the default app labels in platform files still use template naming in some places

## Tech Stack

- Flutter
- Dart
- Web3Auth Flutter SDK
- XMTP backend bridge
- Hive + Hive Flutter
- Flutter Secure Storage
- Shared Preferences
- HTTP
- WebSocket Channel

## Project Structure

```text
meshlix_app/
+- assets/                     # Logos and app branding assets
+- lib/
   +- controllers/            # UI-facing state and chat orchestration
   +- db/                     # Hive setup and local data models
   +- screens/                # Auth, home, chats, contacts, splash, profile
   +- services/
      +- api/                 # Backend HTTP config and API client
      +- auth/                # Web3Auth login and user hydration
      +- session/             # Session persistence helpers
      +- socket/              # Backend WebSocket connection
      +- storage/             # Secure key storage and user storage
      +- sync/                # Initial sync, realtime sync, retry logic
   +- theme/                  # Colors and app theme
   +- widgets/                # Reusable auth UI widgets
+- test/                      # Flutter tests
+- .env.example               # Example runtime configuration
+- pubspec.yaml               # Dependencies and Flutter config
```

## Architecture

Meshlix uses a split architecture:

1. The Flutter app handles UI, authentication, local persistence, and client state.
2. The Node.js backend initializes XMTP clients using the authenticated wallet's private key.
3. The backend exposes REST endpoints for session setup, message sending, sync, consent updates, and capability checks.
4. The backend also pushes real-time message and status events back to the app over WebSocket.

At startup, the app:

1. loads `.env`
2. initializes Hive
3. restores local session and stored users
4. restores the authenticated user if possible
5. initializes backend + socket + sync services for the active wallet
6. routes to either the auth flow or the main navigation UI

## Prerequisites

Before running the Flutter app, make sure you have:

- Flutter installed and available in `PATH`
- a Flutter SDK version compatible with Dart `^3.11.1`
- Android Studio or Xcode set up for your target platform
- Java 17 for Android builds
- Android `minSdk 26` or above
- the Meshlix backend running locally or on your LAN
- a Web3Auth project with a valid client ID
- a Reown / WalletConnect project ID if you plan to enable wallet connection later

Backend requirement:

- Node.js `>= 22.0.0`

## Environment Configuration

Create a `.env` file inside `meshlix_app/` by copying `.env.example`.

```bash
Copy-Item .env.example .env
```

Example values:

```env
WEB3AUTH_CLIENT_ID=your_web3auth_client_id
WEB3AUTH_NETWORK=sapphire_devnet
WALLETCONNECT_PROJECT_ID=your_reown_project_id
BACKEND_URL=http://192.168.1.2:3000
BACKEND_WS_URL=ws://192.168.1.2:3000
```

### Environment Variables

`WEB3AUTH_CLIENT_ID`
- Your Web3Auth client ID.

`WEB3AUTH_NETWORK`
- Use `sapphire_devnet` for development or `sapphire_mainnet` for production.

`WALLETCONNECT_PROJECT_ID`
- Reserved for wallet connection setup. The app includes the config path, but external wallet login is not finished yet.

`BACKEND_URL`
- Base HTTP URL for the Meshlix backend.
- When testing on a physical device, use your computer's LAN IP, not `localhost`.

`BACKEND_WS_URL`
- Optional explicit WebSocket URL.
- If omitted, the app derives it automatically from `BACKEND_URL`.

## Backend Dependency

This Flutter app depends on the backend in the sibling [`backend/`](../backend) directory.

From the repository root:

```bash
cd backend
npm install
npm run dev
```

The Flutter app expects the backend to expose:

- `GET /health`
- `POST /session/init`
- `POST /send-message`
- `GET /messages`
- `GET /conversations`
- `POST /conversations/consent`
- `GET /can-message`
- `POST /session/disconnect`

## Getting Started

From the Flutter app directory:

```bash
cd meshlix_app
flutter pub get
```

If you regenerate Hive adapters or other generated files:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Run the app:

```bash
flutter run
```

## Platform Notes

### Android

- `minSdk` is set to `26`
- internet permission is already declared
- custom URL scheme handling for `meshlix://auth` is already configured
- testing on a physical Android phone requires `BACKEND_URL` to point to your machine's LAN IP

### iOS

- URL scheme support for Web3Auth redirect is configured in `Info.plist`
- bundle identifiers are still example values and should be updated before release

### Web / Desktop

- project folders exist for web, Windows, Linux, and macOS
- the main integration path appears focused on mobile auth and mobile device testing
- if you target web or desktop, verify Web3Auth and backend connectivity behavior for your platform before shipping

## Typical Development Flow

1. Start the backend.
2. Create or update `meshlix_app/.env`.
3. Run `flutter pub get`.
4. Launch the app on a simulator, emulator, or physical device.
5. Sign in with Google or email OTP.
6. Let the app initialize backend session, socket connection, and initial sync.
7. Start a chat using another XMTP-enabled wallet address.

## Data Storage

Meshlix stores data in multiple places:

- `flutter_secure_storage` for private keys
- `SharedPreferences` for lightweight session metadata
- Hive for conversations, contacts, and messages

Local data is isolated per wallet address, which allows multi-user usage on the same device without mixing chat history.

## Messaging Behavior

The app is designed to be offline-first:

- outgoing messages are first written to the local database
- messages are marked pending until backend delivery succeeds
- failed sends can be retried automatically on initialization
- incoming messages update local Hive state through sync and socket listeners

Consent-aware conversation handling is also built in:

- allowed conversations appear in the main chat list
- unknown conversations appear as message requests
- requests can be accepted or declined

## Security Notes

- private keys are not stored in `SharedPreferences`
- private keys are saved per wallet in secure storage
- backend access is session-token based after wallet initialization
- backend sessions expire after idle timeout unless refreshed by activity

Important:

- the backend receives the wallet private key during session initialization so it can create and operate the XMTP client
- use trusted infrastructure and secure transport before deploying beyond local development

## Useful Commands

```bash
flutter analyze
flutter test
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

Backend:

```bash
cd backend
npm run dev
```

## Troubleshooting

### App cannot reach backend

- confirm the backend is running
- confirm `BACKEND_URL` and `BACKEND_WS_URL` are correct
- use your computer LAN IP for real devices
- verify both phone and computer are on the same network

### XMTP initialization fails after login

- confirm `WEB3AUTH_CLIENT_ID` is valid
- confirm the backend started successfully
- check backend logs for XMTP client initialization errors

### Messages do not appear in real time

- verify the WebSocket URL is correct
- confirm the backend session token is still valid
- re-open the app to force service reinitialization

### Address cannot be messaged

- the destination wallet may not be reachable on XMTP yet
- use the backend `can-message` capability check path already integrated in the app

## Related Project Docs

Additional documentation already present in this folder:

- `TESTING_GUIDE.md`
- `XMTP_USAGE_GUIDE.md`
- `XMTP_TROUBLESHOOTING.md`
- `IMPLEMENTATION_COMPLETE.md`
- `PHASES_COMPLETE_SUMMARY.md`

## Cleanup Before Production

Before publishing the app, update:

- app name and branding strings in platform files
- Android `applicationId`
- iOS bundle identifier
- release signing configuration
- production backend URLs
- Web3Auth production network and credentials
- transport security and secret handling strategy

## License

No license file is currently included in this project. Add one if you plan to distribute the app publicly.
