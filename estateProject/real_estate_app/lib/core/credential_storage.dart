import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CredentialStorage {
  static const _secure = FlutterSecureStorage();

  static Future<void> write(String key, String value) async {
    try {
      await _secure.write(key: key, value: value);
    } on MissingPluginException {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('_fallback_$key', value);
    }
  }

  static Future<String?> read(String key) async {
    try {
      return await _secure.read(key: key);
    } on MissingPluginException {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('_fallback_$key');
    }
  }


  static Future<void> delete(String key) async {
    try {
      await _secure.delete(key: key);
    } on MissingPluginException {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('_fallback_$key');
    }
  }


  static Future<bool> secureAvailable() async {
    try {
      await _secure.write(key: '__probe__', value: '1');
      await _secure.delete(key: '__probe__');
      return true;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return true;
    }
  }
}
