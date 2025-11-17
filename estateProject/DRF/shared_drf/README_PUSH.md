# Push Notification Service

This module wires Firebase Cloud Messaging (FCM) delivery into the DRF layer so
mobile clients receive status-bar notifications alongside existing WebSocket
updates.

## Configuration

1. Install dependencies (already in `requirements.txt`):
   ```bash
   pip install firebase-admin
   ```

2. Provide server credentials via environment variables before launching Django:
   ```bash
   set FIREBASE_CREDENTIALS_PATH="c:\\path\\to\\service_account.json"
   set FIREBASE_DEFAULT_ICON=ic_stat_notification
   set FIREBASE_DEFAULT_COLOR=#075E54
   ```
   - `FIREBASE_CREDENTIALS_PATH` may be a filesystem path or the raw JSON
     content of the service-account key.
   - Icon/color customise Android status-bar appearance for high-priority
     notifications.

## API Endpoints

Device tokens are managed through DRF routes (see `DRF/urls.py`):

- `POST /api/device-tokens/register/`
  ```json
  {
    "token": "<FCM device token>",
    "platform": "android",
    "app_version": "1.0.0",
    "device_model": "Pixel 7"
  }
  ```
- `DELETE /api/device-tokens/register/?token=<token>` removes a token.
- `GET /api/device-tokens/` returns the authenticated user’s registered tokens.

Clients should register after every token refresh (Firebase can rotate tokens at
any time) and delete their token on logout.

## Automatic Dispatch

- `UserNotification` creations trigger pushes via `send_user_notification_push`
  (alongside existing WebSocket broadcasts).
- New chat `Message` rows trigger `send_chat_message_push` so recipients get
  alerts even if the app is backgrounded.

Inactive tokens (e.g. uninstalled apps) are detected from FCM error codes and
are automatically marked inactive to avoid repeated failures.

## Extending Payloads

All payload fields are stringified before sending to FCM. Add new keys in
`push_service.py` to keep Flutter navigation in sync with backend routes.

## Troubleshooting

- If you see `firebase_admin package not installed`, ensure dependencies are
  installed in the server environment.
- If pushes silently fail, confirm the service-account credentials have the
  `firebase.messaging` scope and that `FIREBASE_CREDENTIALS_PATH` is resolvable.
- Check Django logs for `Marked X device token(s) inactive` entries to prune old
  tokens or debug delivery issues.
