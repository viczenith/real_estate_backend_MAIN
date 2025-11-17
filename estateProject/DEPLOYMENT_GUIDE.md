# Deployment & Mobile Testing Guide

This guide walks you through deploying the Django backend to Render and distributing the Flutter mobile app via Firebase App Distribution.

---

## 1. Prerequisites

- GitHub repository for the project
- Render account (free tier)
- Firebase project & CLI (for mobile distribution)
- Flutter SDK installed locally
- Android keystore for signed builds (optional for testing)

---

## 2. Backend deployment to Render

### 2.1 Repository setup
1. Ensure `requirements.txt` is up to date.
2. Review `render-build.sh` (runs pip install + collectstatic).
3. Confirm `render.yaml` exists at repo root (added in this workspace).

### 2.2 Configure Render service
1. Sign in at [https://render.com](https://render.com).
2. Click **New + → Web Service**.
3. Connect GitHub repo and select main branch.
4. Build command: `./render-build.sh`.
5. Start command: `gunicorn estateProject.wsgi:application` (already set in render.yaml).
6. Choose **Free** plan.
7. Add environment variables:
   - `SECRET_KEY` (generate a secure value)
   - `DEBUG=False`
   - Database credentials (`POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_HOST`, `POSTGRES_PORT`)
   - `REDIS_URL` (optional; add when using Channels/Redis)
8. Deploy; wait until status shows **Live**.

### 2.3 Database setup
- Render offers managed PostgreSQL. Provision one, note connection settings, and populate as needed using Django migrations: `python manage.py migrate` (can run via Render Shell). 
- To load demo data, consider `python manage.py loaddata <fixture>.json`.

### 2.4 Static files & media
- Static files are collected to `/staticfiles` during build.
- For user uploads, configure an S3-compatible storage if needed (Render disks are ephemeral). Consider AWS S3, DigitalOcean Spaces, or Firebase Storage.

### 2.5 Custom domain (optional)
- In Render dashboard, open the service → **Settings** → **Custom Domains**.
- Follow instructions to point DNS and enable automatic SSL.

---

## 3. Mobile app distribution via Firebase App Distribution

### 3.1 Firebase setup
1. Visit [https://console.firebase.google.com](https://console.firebase.google.com) and create a project (if not already).
2. Add Android app (package name matches Flutter project). Download `google-services.json` into `android/app/`.

> **Production tip:** `google-services.json` is ignored by git. Copy `android/app/google-services.json.template` to `google-services.json` locally and fill the values or generate via Firebase console. In CI, fetch the file from secure storage before builds.
3. Enable App Distribution in Firebase Console.

### 3.2 Install Firebase CLI
```bash
npm install -g firebase-tools
firebase login
```

### 3.3 Integrate App Distribution plugin
In `android/build.gradle` ensure the plugin repository is available:
```gradle
buildscript {
    dependencies {
        classpath 'com.google.firebase:firebase-appdistribution-gradle:5.1.0'
    }
}
```

In `android/app/build.gradle` apply the plugin:
```gradle
plugins {
    id 'com.google.firebase.appdistribution'
}
```

Configure distribution (replace placeholders):
```gradle
firebaseAppDistribution {
    serviceCredentialsFile="../path/to/firebase-service-account.json"
    appId="1:1234567890:android:abcdef123456"
    testers="tester1@example.com,tester2@example.com"
    releaseNotes="Initial QA build"
}
```

### 3.4 Generate a build
```bash
flutter clean
flutter build apk --release \
  --dart-define=FIREBASE_ANDROID_API_KEY=$FIREBASE_ANDROID_API_KEY \
  --dart-define=FIREBASE_ANDROID_APP_ID=$FIREBASE_ANDROID_APP_ID \
  --dart-define=FIREBASE_ANDROID_MESSAGING_SENDER_ID=$FIREBASE_ANDROID_MESSAGING_SENDER_ID \
  --dart-define=FIREBASE_ANDROID_PROJECT_ID=$FIREBASE_ANDROID_PROJECT_ID \
  --dart-define=FIREBASE_ANDROID_STORAGE_BUCKET=$FIREBASE_ANDROID_STORAGE_BUCKET
```
(or build an app bundle: `flutter build appbundle`)

### 3.5 Upload to testers
Use Gradle task:
```bash
cd android
./gradlew appDistributionUploadRelease \
  -PFIREBASE_APP_DIST_CREDENTIALS="../path/to/firebase-service-account.json" \
  -PFIREBASE_APP_DIST_APP_ID="1:1234567890:android:abcdef123456" \
  -PFIREBASE_APP_DIST_GROUPS="qa-testers" \
  -PFIREBASE_APP_DIST_RELEASE_NOTES="Initial QA build"
```
Or via Firebase CLI:
```bash
firebase appdistribution:distribute build/app/outputs/apk/release/app-release.apk \
  --app "1:1234567890:android:abcdef123456" \
  --groups "qa-testers" \
  --release-notes "Initial QA build"
```

### 3.6 Invite testers
- Testers receive an email from Firebase.
- They install the Firebase App Tester app, accept invite, and download the build.

### 3.7 Gather feedback
- Encourage testers to submit feedback via Firebase; integrate Crashlytics for crash reports.

---

## 4. iOS distribution (optional)
- Requires Apple Developer account.
- Build IPA in Xcode or via Flutter (`flutter build ipa`).
- Upload through Transporter or App Store Connect for TestFlight.
- Invite testers up to 10,000 via email or public link.

---

## 5. Continuous integration (optional enhancements)
- Add GitHub Actions workflow to deploy on push.
- Automate Firebase distribution after successful build.
- Monitor using Render logs and Firebase Crashlytics.

---

## 6. Next steps & tips
- Store secrets securely (Render dashboard or `.env` not committed).
- Use environment-specific settings module if production config diverges.
- Consider enabling HTTPS (Render handles automatically).
- For scaling beyond free tier, upgrade Render service or migrate to a more robust platform.

Happy deploying!
