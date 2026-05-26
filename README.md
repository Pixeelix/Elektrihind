# NordPrice

SwiftUI iOS app for Nord Pool electricity prices in Estonia, Latvia, Lithuania, and Finland.

## Notifications

Price threshold notifications now use Firebase instead of the old Render backend.

- The app requests notification permission, registers with APNs, receives an FCM token, signs in anonymously with Firebase Auth, and calls `syncNotificationDevice`.
- Firebase Functions stores each device's notification preferences in Firestore.
- `checkTomorrowPrices` runs on Cloud Scheduler at `14:15`, `14:45`, `15:15`, `15:45`, `16:15`, and `16:45` Europe/Tallinn time, checks the complete 15-minute price set for tomorrow, compares each user's selected market time unit (`15min` or hourly average), and sends FCM notifications.
- Firestore client access is disabled in `firestore.rules`; only Cloud Functions writes notification device documents.

### Firebase Setup

1. Install iOS dependencies:

   ```bash
   pod install
   ```

2. In Apple Developer, make sure the `koodipardik.Elektrihind` App ID has **Push Notifications** enabled.

3. In Xcode, make sure the main app target has the **Push Notifications** capability. The entitlement is already present in `Elektrihind/NordPrice.entitlements`.

4. In Firebase Console for `elektrihind-76019`, open **Project settings -> Cloud Messaging** and upload an APNs authentication key for the iOS app.

5. Enable **Authentication -> Sign-in method -> Anonymous**.

6. Create a Firestore database.

7. Make sure the Firebase project is on the Blaze plan and that the Cloud Scheduler API is enabled for scheduled Functions.

8. Install and deploy Firebase backend code:

   ```bash
   npm install -g firebase-tools
   firebase login
   firebase use elektrihind-76019
   cd functions
   npm install
   npm run build
   cd ..
   firebase deploy --only functions,firestore:rules
   ```

9. Test on a physical iPhone for reliable APNs/FCM validation.

### Useful Commands

```bash
firebase functions:log --only syncNotificationDevice,checkTomorrowPrices
firebase deploy --only functions
firebase deploy --only firestore:rules
```
