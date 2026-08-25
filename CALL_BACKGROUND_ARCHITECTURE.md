# Call Background & Production VoIP Architecture Audit

> **Bimo-Bond Calling Engine Architecture Blueprint**  
> Compliant with Android Full-Screen Intent (SDK 24-34+), Apple PushKit / CallKit (`CXProvider`), Socket.IO signaling, and LiveKit WebRTC.

---

## 1. Audit of Existing System

### 1.1 Existing Implementations
1. **FCM (Android)**:
   - `PushNotificationService` registers `FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler)`.
   - Incoming call FCM data payloads trigger `CallkitService.instance.showIncomingCall(data)`.
   - Android permissions configured: `USE_FULL_SCREEN_INTENT`, `MANAGE_OWN_CALLS`, `FOREGROUND_SERVICE_PHONE_CALL`, `SYSTEM_ALERT_WINDOW`, `DISABLE_KEYGUARD`, `TURN_SCREEN_ON`.
   - `AndroidParams` uses system native notification banners (`isCustomNotification: false`, `isShowFullLockedScreen: true`).

2. **APNs & CallKit (iOS)**:
   - `Info.plist` defines `UIBackgroundModes`: `voip`, `fetch`, `remote-notification`.
   - `CallkitService` uses `flutter_callkit_incoming` (`IOSParams` with `supportsVideo`, `audioSessionActive: true`).
   - Camera and Microphone usage descriptions set (`NSCameraUsageDescription`, `NSMicrophoneUsageDescription`).

3. **WebRTC & LiveKit**:
   - `LiveKitCallService` manages `lk.Room`, camera/microphone track publication, earpiece/speaker toggle, and connection lifecycle.
   - WebRTC session is established **only upon answering/starting** a call (`AcceptCallSessionEvent`), never on raw push notification receipt.

4. **Flutter UI & State Machine**:
   - Centralized `CallSession` state machine (`CallSessionStatus`) managed by `CallController` and `CallSessionManager`.
   - `GlobalCallListener` enforces single-route navigator management (`/active-call`, `/incoming-call`) without duplicate screen stacking.
   - `KeyguardService` handles dynamic lockscreen window elevation (`setShowWhenLocked`) and keyguard dismissal (`requestDismissKeyguard`).

5. **SDK Targets**:
   - **Android**: `compileSdk` = 34+, `minSdk` = 24 (`Android 7.0`), Java 17 compatibility enabled.
   - **iOS**: Deployment target = iOS 13.0+.

---

## 2. Identified Problems & Gaps

1. **iOS Background / Terminated Wakeup**:
   - iOS standard APNs alert notifications cannot reliably wake a killed Flutter app for real-time VoIP calls.
   - **Required Solution**: Apple PushKit (`PKPushRegistry`) with `CXProvider` / CallKit framework must receive VoIP push tokens for 100% instant system incoming call UI wakeup when killed/locked.

2. **Android Heavy OEM Process Killing**:
   - Certain Android vendors (Xiaomi MIUI, Huawei EMUI, Samsung OneUI) kill background isolates if the app is removed from recent apps.
   - **Required Solution**: High-priority FCM data messages coupled with Android `FOREGROUND_SERVICE_PHONE_CALL` and `USE_FULL_SCREEN_INTENT` channel elevation.

3. **Payload Uniformity**:
   - Standardizing incoming call payload schema across FCM, PushKit, Socket.IO, and HTTP API endpoints.

---

## 3. Standard Call Payload Schema

```json
{
  "type": "incoming_call",
  "callId": "550e8400-e29b-41d4-a716-446655440000",
  "callerId": "user-uuid-123",
  "callerName": "Hazem",
  "callerAvatar": "https://cdn.bimobond.app/avatars/hazem.jpg",
  "callType": "audio",
  "timestamp": "2026-08-19T16:35:00.000Z",
  "expiresAt": "2026-08-19T16:35:45.000Z"
}
```

*For video calls: `"callType": "video"`. Calls are identified strictly by `callId`.*

---

## 4. Centralized Call State Machine (`CallSessionStatus`)

```
                      ┌───────────────┐
                      │     IDLE      │
                      └───────┬───────┘
                              │
                    ┌─────────┴─────────┐
                    ▼                   ▼
           ┌────────────────┐  ┌────────────────┐
           │ OUTGOING_CALL  │  │ INCOMING_RING  │
           └───────┬────────┘  └───────┬────────┘
                   │                   │
                   ▼                   ▼
           ┌────────────────┐  ┌────────────────┐
           │ OUTGOING_RING  │  │   ACCEPTING    │
           └───────┬────────┘  └───────┬────────┘
                   │                   │
                   └─────────┬─────────┘
                             ▼
                    ┌────────────────┐
                    │   CONNECTING   │
                    └───────┬────────┘
                            │
                            ▼
                    ┌────────────────┐
                    │   CONNECTED    │
                    └───────┬────────┘
                            │
              ┌─────────────┼─────────────┐
              ▼             ▼             ▼
       ┌─────────────┐┌───────────┐┌─────────────┐
       │RECONNECTING ││  DECLINED ││   TIMEOUT   │
       └──────┬──────┘└───────────┘└─────────────┘
              │             │             │
              ▼             ▼             ▼
       ┌─────────────┐┌───────────┐┌─────────────┐
       │   FAILED    ││ CANCELLED ││    ENDED    │
       └─────────────┘└───────────┘└─────────────┘
```

### Complete State Enum Matrix
1. `IDLE`: Initial default state.
2. `OUTGOING`: Initiating call request to signaling server.
3. `RINGING`: Receiver's phone is ringing.
4. `ACCEPTING`: User pressed ACCEPT; validating session and retrieving LiveKit credentials.
5. `CONNECTING`: Establishing LiveKit WebRTC PeerConnection & media tracks.
6. `CONNECTED`: WebRTC media flowing bidirectionally.
7. `RECONNECTING`: Network switch (Wi-Fi ↔ 4G) or temporary packet loss recovery.
8. `DECLINED`: User pressed DECLINE / rejected by target device.
9. `BUSY`: Target user is in another call.
10. `CANCELLED`: Caller hung up before receiver answered.
11. `TIMEOUT`: No answer within configured window (30-45s).
12. `FAILED`: Media connection or signaling failure.
13. `ENDED`: Call ended normally by either participant.

---

## 5. Android Architecture Flow

```
NestJS Backend
  │ (FCM High-Priority Data Push)
  ▼
Android System FCM Receiver
  │ (Wake Lock + Full-Screen Intent Permission Check)
  ▼
CallkitIncomingActivity / Telecom CallStyle Notification
  │ (Ringtone + Vibration + Lockscreen Display)
  ├──► DECLINE: PendingIntent → POST /calls/:id/reject → Stop Ringing on Caller
  └──► ACCEPT: PendingIntent → Launch MainActivity → KeyguardService.setShowWhenLocked(true)
          │
          ▼
     CallController.acceptCall(callId)
          │
          ▼
     POST /calls/:id/accept → Receive LiveKit Token
          │
          ▼
     LiveKit WebRTC Connection → Open ActiveCallScreen
```

---

## 6. iOS Architecture Flow

```
NestJS Backend
  │ (APNs VoIP Push via PushKit)
  ▼
iOS PushKit (PKPushRegistry)
  │ (Wakes App Process in Background / Terminated Mode)
  ▼
CallKit Framework (CXProvider / CXCallUpdate)
  │ (System Incoming Call UI / Lockscreen Banner)
  ├──► DECLINE: CXEndCallAction → POST /calls/:id/reject
  └──► ACCEPT: CXAnswerCallAction → Keyguard / Window Active
          │
          ▼
     CallController.acceptCall(callId)
          │
          ▼
     POST /calls/:id/accept → Receive LiveKit Token
          │
          ▼
     LiveKit WebRTC Connection → Present ActiveCallScreen
```

---

## 7. Multi-Device & Cancellation Flows

### 7.1 Multi-Device Answer / Dismissal
- When User B is logged into **Phone A**, **Phone B**, and **Tablet C**:
  - Incoming push triggers system call UI on all 3 devices.
  - When User B answers on **Phone A**:
    - Backend emits `call.accepted` socket event and sends FCM/APNs cancellation data push to **Phone B** & **Tablet C**.
    - **Phone B** and **Tablet C** immediately call `FlutterCallkitIncoming.endAllCalls()`, dismissing the call banner without leaving a missed call alert.

### 7.2 Caller Cancellation Before Answer
- Caller A presses **Cancel Call**:
  - Backend emits `call.cancelled` socket event + FCM `CALL_CANCELLED` push to User B.
  - User B's device calls `FlutterCallkitIncoming.endAllCalls()`, dismisses the ringing screen instantly, and prevents answering expired calls.

---

## 8. Testing Matrix

### 8.1 Android Test Matrix
| Scenario | Network | State | Expected Outcome |
| :--- | :--- | :--- | :--- |
| App Foreground + Audio | Wi-Fi | Ringing | In-app screen / banner; clean answer & LiveKit audio |
| App Foreground + Video | 4G | Ringing | In-app screen / banner; camera & mic published |
| App Background + Audio | Wi-Fi | Locked | System CallKit banner; Accept opens ActiveCallScreen |
| App Background + Video | 4G | Unlocked | System CallKit banner; Accept opens ActiveCallScreen with camera |
| App Removed from Recents + Audio | 5G | Locked | Native CallKit notification wakes device; Accept connects call |
| App Removed from Recents + Video | 4G ↔ Wi-Fi | Locked | Native CallKit notification wakes device; WebRTC reconnects on network switch |
| App Process Killed + Audio | Wi-Fi | Idle/Sleep | High-priority FCM wakes native handler; Accept launches app to active call |
| App Process Killed + Video | 5G | Idle/Sleep | High-priority FCM wakes native handler; Accept connects video |
| Screen Locked + Audio | 4G | Locked | Lockscreen call UI appears; ending call re-locks phone |
| Screen Locked + Video | Wi-Fi | Locked | Lockscreen call UI appears; unlocking with passcode preserves call |

### 8.2 iOS Test Matrix
| Scenario | Network | State | Expected Outcome |
| :--- | :--- | :--- | :--- |
| App Foreground + Audio | Wi-Fi | Ringing | Native CallKit / UI banner; clean answer & LiveKit audio |
| App Foreground + Video | 4G | Ringing | Native CallKit / UI banner; camera & mic published |
| App Background + Audio | Wi-Fi | Locked | System CallKit UI; Accept opens ActiveCallScreen |
| App Background + Video | 4G | Unlocked | System CallKit UI; Accept opens ActiveCallScreen with camera |
| App Terminated + Audio | 5G | Locked | PushKit wakes app; CallKit UI displayed; Accept connects call |
| App Terminated + Video | 4G ↔ Wi-Fi | Locked | PushKit wakes app; CallKit UI displayed; WebRTC reconnects on network switch |
| Screen Locked + Audio | 4G | Locked | System CallKit lockscreen UI; ending call re-locks phone |
| Screen Locked + Video | Wi-Fi | Locked | System CallKit lockscreen UI; unlocking with passcode preserves call |

---

## 9. Security & Authorization Guidelines

1. **Strict Token Validation**:
   - Backend MUST authorize `callId` against the authenticated `receiverId`. Malicious clients cannot accept calls assigned to other user IDs.
2. **Call Expiration Enforcement**:
   - Backend rejects calls older than `expiresAt` (default 45s).
3. **Lockscreen App Isolation**:
   - `KeyguardService` ensures that answering a call while the phone is locked displays ONLY the active call UI over the lockscreen. Exiting or minimizing the call screen forces OS device passcode/biometric authentication.
