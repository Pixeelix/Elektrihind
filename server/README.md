# Elektrihind Push Server

This service makes the app's price alerts reliable by moving the daily check to a server:

1. The iOS app registers with APNs and sends its device token plus notification settings here.
2. A scheduled server job fetches tomorrow's Elering prices.
3. The server sends APNs alerts to devices whose thresholds are crossed.

## Apple Setup

1. Open Apple Developer -> Certificates, Identifiers & Profiles -> Identifiers.
2. Select the app identifier for `koodipardik.Elektrihind`.
3. Enable **Push Notifications**.
4. Open Keys and create an **Apple Push Notifications service (APNs)** key.
5. Download the `.p8` file once, then note:
   - Team ID: currently `39G5236S72`
   - Key ID
   - Bundle ID: `koodipardik.Elektrihind`

Never put the `.p8` key in the iOS app. It belongs only on the server.

## Local Setup

```bash
cd server
cp .env.example .env
npm install
createdb elektrihind_push
npm run migrate
npm run dev
```

Fill `.env` with your real APNs values. `APNS_PRIVATE_KEY_BASE64` is easiest for hosted environments:

```bash
base64 -i AuthKey_XXXXXXXXXX.p8
```

For a physical iPhone, `localhost` points at the phone, not your Mac. Use a tunnel such as ngrok or deploy first, then set `PushBackendBaseURL` in `Elektrihind/Info.plist` to that HTTPS URL.

## Deploy On Render

The repo includes a root-level `render.yaml` Blueprint that creates:

- `elektrihind-push-api`: Node web service
- `elektrihind-push-db`: private PostgreSQL database
- `elektrihind-price-check`: cron job that runs every 30 minutes from 11:15-15:45 UTC

That UTC window covers 14:15 Tallinn time in both summer and winter. Runs before Elering has complete data exit successfully and send nothing.

Steps:

1. Push this repo to GitHub/GitLab/Bitbucket.
2. Open Render Dashboard -> New -> Blueprint.
3. Connect the repo and select the branch with `render.yaml`.
4. Render will ask for secret values:
   - `APNS_KEY_ID`
   - `APNS_PRIVATE_KEY_BASE64`
5. Deploy the Blueprint.
6. Copy the public URL of `elektrihind-push-api`.
7. Set that URL as `PushBackendBaseURL` in `Elektrihind/Info.plist`.

The Blueprint uses Render's internal PostgreSQL connection string and runs `npm run migrate` before starting the web service.

## App Setup

1. In Xcode, open `Elektrihind.xcworkspace`.
2. Select the `Elektrihind` target.
3. Confirm **Signing & Capabilities** includes:
   - App Groups
   - Push Notifications
4. Set `PushBackendBaseURL` in `Elektrihind/Info.plist`, for example:

```xml
<key>PushBackendBaseURL</key>
<string>https://your-push-server.example.com</string>
```

The app syncs settings whenever the user changes notification preferences. Debug builds send `sandbox` APNs tokens. Release and TestFlight builds send `production` tokens.

## Database

Run:

```bash
npm run migrate
```

To see registered devices:

```bash
psql "$DATABASE_URL" -c "select installation_id, region, apns_environment, notify_max_enabled, notify_max_raw_mwh from device_settings;"
```

## Test Push

After running the app on a physical device and enabling notifications:

```bash
curl -X POST \
  "https://your-push-server.example.com/admin/test-push/<installation_id>" \
  -H "Authorization: Bearer $ADMIN_API_KEY"
```

## Daily Job

Trigger the price check after tomorrow's prices are usually available. Prefer a scheduler that supports the `Europe/Tallinn` timezone and run every 30 minutes from 14:15 to 16:15. The job is idempotent because each device stores the last notification date per alert type.

HTTP trigger:

```bash
curl -X POST \
  "https://your-push-server.example.com/admin/check-prices" \
  -H "Authorization: Bearer $ADMIN_API_KEY"
```

CLI trigger:

```bash
cd server
npm run check:prices
```

If Elering has not published a complete day yet, the job returns `dataReady: false` and sends nothing.
