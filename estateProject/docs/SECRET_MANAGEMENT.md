# Secret Management Guide

This guide centralises how to provision and rotate secrets across environments.

## 1. Render environment variables

1. Open your Render service → **Environment** tab.
2. Create or update the variables below (values in parentheses are examples only):
   - `SECRET_KEY` (`django-insecure-...`)
   - `DEBUG` (`False`)
   - `ALLOWED_HOSTS` (`api.example.com`)
   - `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_HOST`, `POSTGRES_PORT`
   - `REDIS_URL`
   - `FIREBASE_CREDENTIALS_PATH` (absolute path in attached disk *or* JSON string)
   - `FIREBASE_DEFAULT_*` overrides as needed
3. After saving, trigger a manual deploy or push to main.

### Optional: automate via Render API

```bash
curl -X PATCH \
  -H "Authorization: Bearer $RENDER_API_KEY" \
  -H "Content-Type: application/json" \
  "https://api.render.com/v1/services/$RENDER_SERVICE_ID/env-vars" \
  --data '{"envVars":[{"key":"SECRET_KEY","value":"'$SECRET_KEY'"}]}'
```

## 2. GitHub Actions secrets

Add the following under **Settings → Secrets and variables → Actions**:

| Secret | Purpose |
|--------|---------|
| `RENDER_SERVICE_ID` | Used by `render-deploy.yml` to trigger deploys |
| `RENDER_API_KEY` | API token for Render |
| `FIREBASE_APP_DIST_APP_ID` | Gradle property for App Distribution |
| `FIREBASE_APP_DIST_CREDENTIALS` | Base64 service-account JSON (decode in workflow) |
| `FIREBASE_APP_DIST_GROUPS` | Comma-separated tester group IDs |
| `FIREBASE_APP_DIST_RELEASE_NOTES` | Default release notes |
| `FIREBASE_ANDROID_API_KEY` etc. | Values passed to Flutter via `--dart-define` |

Example GitHub Action usage:

```yaml
- name: Decode Firebase service account
  run: |
    echo "$FIREBASE_APP_DIST_CREDENTIALS" | base64 --decode > android/firebase-app-distribution.json
```

## 3. Local development

1. Copy `.env.example` → `.env` and fill the values.
2. Copy `real_estate_app/android/app/google-services.json.template` → `google-services.json`.
3. Export Dart defines before running Flutter builds:

```bash
export FIREBASE_ANDROID_API_KEY="..."
export FIREBASE_ANDROID_APP_ID="..."
export FIREBASE_ANDROID_MESSAGING_SENDER_ID="..."
export FIREBASE_ANDROID_PROJECT_ID="..."
export FIREBASE_ANDROID_STORAGE_BUCKET="..."
```

4. (Optional) Store secrets securely using a password manager or OS keychain.

## 4. Rotation checklist

- Generate new Django `SECRET_KEY` (e.g., via `python -c "import secrets; print(secrets.token_urlsafe(50))"`).
- Rotate database password and update Render variables.
- Create a new Firebase service account key (remember to delete old ones).
- Update GitHub Actions secrets and re-run workflows.

## 5. Tracking changes

- Record secret rotations in your internal runbook.
- Use short TTL personal API keys; prefer team-owned automation keys.
