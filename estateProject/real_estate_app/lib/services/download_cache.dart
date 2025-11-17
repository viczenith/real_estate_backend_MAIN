import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class DownloadCache {
  static const String _prefix = 'chat_download_cache_';

  Future<Map<String, String>> readAll(String namespace) async {
    final prefs = await SharedPreferences.getInstance();
    return _readMap(prefs, namespace);
  }

  Future<void> saveEntry(String namespace, String fileId, String path) async {
    final prefs = await SharedPreferences.getInstance();
    final map = _readMap(prefs, namespace);
    map[fileId] = path;
    await _writeMap(prefs, namespace, map);
  }

  Future<void> removeEntry(String namespace, String fileId) async {
    final prefs = await SharedPreferences.getInstance();
    final map = _readMap(prefs, namespace);
    if (map.remove(fileId) != null) {
      await _writeMap(prefs, namespace, map);
    }
  }

  Future<void> clear(String namespace) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$namespace');
  }

  Map<String, String> _readMap(SharedPreferences prefs, String namespace) {
    final raw = prefs.getString('$_prefix$namespace');
    if (raw == null || raw.isEmpty) {
      return <String, String>{};
    }
    try {
      final Map<String, dynamic> decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((key, value) => MapEntry(key, value?.toString() ?? ''));
    } catch (_) {
      return <String, String>{};
    }
  }

  Future<void> _writeMap(
    SharedPreferences prefs,
    String namespace,
    Map<String, String> map,
  ) async {
    await prefs.setString('$_prefix$namespace', jsonEncode(map));
  }
}
