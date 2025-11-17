import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

// This is needed for debugPrint
import 'package:flutter/foundation.dart' show debugPrint;

class DefaultFirebaseOptions {
  static FirebaseOptions? _cachedOptions;
  
  static Future<FirebaseOptions> get currentPlatform async {
    if (_cachedOptions != null) return _cachedOptions!;
    
    if (kIsWeb) {
      throw UnsupportedError('Firebase options have not been configured for web.');
    }
    
    try {
      // Try to load from google-services.json
      _cachedOptions = await _loadFromGoogleServices();
      return _cachedOptions!;
    } catch (e) {
      // Fallback to build-time configuration
      debugPrint('Failed to load Firebase config from google-services.json: $e');
      return _buildTimeOptions();
    }
  }
  
  static Future<FirebaseOptions> _loadFromGoogleServices() async {
    try {
      // For Android, we can read the google-services.json file
      final jsonString = await _loadAsset('android/app/google-services.json');
      final json = jsonDecode(jsonString);
      
      // Get the first client configuration
      final client = (json['client'] as List).first;
      final clientInfo = client['client_info'];
      final projectInfo = json['project_info'];
      
      return FirebaseOptions(
        apiKey: client['api_key'][0]['current_key'],
        appId: clientInfo['mobilesdk_app_id'],
        messagingSenderId: projectInfo['project_number'],
        projectId: projectInfo['project_id'],
        storageBucket: projectInfo['storage_bucket'],
      );
    } catch (e) {
      debugPrint('Error parsing google-services.json: $e');
      rethrow;
    }
  }
  
  static Future<String> _loadAsset(String path) async {
    try {
      return await rootBundle.loadString(path);
    } catch (e) {
      // If running in test or other environment where assets aren't available
      final file = File(path);
      if (await file.exists()) {
        return await file.readAsString();
      }
      rethrow;
    }
  }
  
  static FirebaseOptions _buildTimeOptions() {
    return const FirebaseOptions(
      apiKey: String.fromEnvironment('FIREBASE_ANDROID_API_KEY', 
          defaultValue: 'AIzaSyByuwVHFN7q-5gf87Wmp7P7Q9BLIxUV_4Q'),
      appId: String.fromEnvironment('FIREBASE_ANDROID_APP_ID',
          defaultValue: '1:1007078615485:android:6cf5961afe84aab47e0ad4'),
      messagingSenderId: String.fromEnvironment('FIREBASE_ANDROID_MESSAGING_SENDER_ID',
          defaultValue: '1007078615485'),
      projectId: String.fromEnvironment('FIREBASE_ANDROID_PROJECT_ID',
          defaultValue: 'real-estate-app-935a1'),
      storageBucket: String.fromEnvironment('FIREBASE_ANDROID_STORAGE_BUCKET',
          defaultValue: 'real-estate-app-935a1.firebasestorage.app'),
    );
  }
}
