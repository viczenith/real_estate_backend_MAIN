import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class MessageDeletionStore {
  static const _prefix = 'chat_deleted_for_me_';

  Future<Set<int>> loadDeletedMessageIds(String namespace) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$namespace');
    if (raw == null || raw.isEmpty) return <int>{};
    try {
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((value) => int.tryParse(value.toString()))
          .whereType<int>()
          .toSet();
    } catch (_) {
      return <int>{};
    }
  }

  Future<void> addDeletedMessageId(String namespace, int messageId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = await loadDeletedMessageIds(namespace);
    ids.add(messageId);
    await prefs.setString('$_prefix$namespace', jsonEncode(ids.toList()));
  }

  Future<void> removeDeletedMessageId(String namespace, int messageId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = await loadDeletedMessageIds(namespace);
    if (ids.remove(messageId)) {
      await prefs.setString('$_prefix$namespace', jsonEncode(ids.toList()));
    }
  }

  Future<void> clear(String namespace) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$namespace');
  }
}
