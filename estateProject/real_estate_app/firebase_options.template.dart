import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Firebase options have not been configured for web.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        throw UnsupportedError('Firebase options have not been configured for this platform.');
      default:
        throw UnsupportedError('Firebase options have not been configured for this platform.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: '<API_KEY>',
    appId: '<APP_ID>',
    messagingSenderId: '<MESSAGING_SENDER_ID>',
    projectId: '<PROJECT_ID>',
    storageBucket: '<STORAGE_BUCKET>',
  );
}
