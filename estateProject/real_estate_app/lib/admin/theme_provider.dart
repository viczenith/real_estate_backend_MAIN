import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  Future<void> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final theme = prefs.getString('theme') ?? 'system';
    _themeMode = ThemeMode.values.firstWhere(
      (e) => e.toString() == 'ThemeMode.$theme',
      orElse: () => ThemeMode.system,
    );
    notifyListeners();
  }

  Future<void> setTheme(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme', mode.toString().split('.')[1]);
    notifyListeners();
  }
}
