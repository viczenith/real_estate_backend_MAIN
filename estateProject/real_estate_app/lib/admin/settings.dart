import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'admin_layout.dart'; // Ensure this file exists in your project.
import 'theme_provider.dart';
import 'package:provider/provider.dart';

enum ThemeModeOption { system, light, dark }

class AdminSettings extends StatefulWidget {
  final String token;
  const AdminSettings({required this.token, super.key});

  @override
  State<AdminSettings> createState() => _AdminSettingsState();
}

class _AdminSettingsState extends State<AdminSettings> {
  ThemeModeOption _selectedThemeMode = ThemeModeOption.system;
  String _appVersion = '1.0.0';
  bool _notificationsEnabled = true;
  String _selectedLanguage = 'English';

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
    // Load the saved theme from preferences and update the local state.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      await themeProvider.loadPreferences();
      setState(() {
        switch (themeProvider.themeMode) {
          case ThemeMode.dark:
            _selectedThemeMode = ThemeModeOption.dark;
            break;
          case ThemeMode.light:
            _selectedThemeMode = ThemeModeOption.light;
            break;
          case ThemeMode.system:
          // ignore: unreachable_switch_default
          default:
            _selectedThemeMode = ThemeModeOption.system;
            break;
        }
      });
    });
  }

  Future<void> _loadPackageInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = 'v${packageInfo.version}';
    });
  }

  // Update the local state and the global theme.
  void _updateTheme(ThemeModeOption newMode) {
    setState(() {
      _selectedThemeMode = newMode;
    });
    ThemeMode themeMode;
    if (newMode == ThemeModeOption.dark) {
      themeMode = ThemeMode.dark;
    } else if (newMode == ThemeModeOption.light) {
      themeMode = ThemeMode.light;
    } else {
      themeMode = ThemeMode.system;
    }
    Provider.of<ThemeProvider>(context, listen: false).setTheme(themeMode);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AdminLayout(
      pageTitle: "Settings",
      token: widget.token,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('Appearance', theme),
          _buildThemeSelector(theme),
          const SizedBox(height: 24),
          _buildSectionHeader('Preferences', theme),
          _buildLanguageSelector(),
          _buildNotificationSwitch(),
          const SizedBox(height: 24),
          _buildSectionHeader('About', theme),
          _buildVersionInfo(),
          const SizedBox(height: 40),
          _buildAdvancedSettings(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildThemeSelector(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            _buildThemeTile(
              'Light Theme',
              Icons.light_mode_rounded,
              ThemeMode.light,
            ),
            _buildThemeTile(
              'Dark Theme',
              Icons.dark_mode_rounded,
              ThemeMode.dark,
            ),
            _buildThemeTile(
              'System Default',
              Icons.phone_android_rounded,
              ThemeMode.system,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeTile(String title, IconData icon, ThemeMode mode) {
    final themeOption = mode == ThemeMode.light
        ? ThemeModeOption.light
        : mode == ThemeMode.dark
            ? ThemeModeOption.dark
            : ThemeModeOption.system;
    final isSelected = _selectedThemeMode == themeOption;

    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      trailing: isSelected
          ? Icon(Icons.check_circle_rounded,
              color: Theme.of(context).colorScheme.primary)
          : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      tileColor: isSelected
          ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
          : Colors.transparent,
      onTap: () => _updateTheme(themeOption),
    );
  }

  Widget _buildLanguageSelector() {
    return ListTile(
      leading: const Icon(Icons.language_rounded),
      title: const Text('App Language'),
      subtitle: Text(_selectedLanguage),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: _showLanguageSelector,
    );
  }

  Widget _buildNotificationSwitch() {
    return SwitchListTile(
      title: const Text('Notifications'),
      subtitle: const Text('Enable push notifications'),
      value: _notificationsEnabled,
      onChanged: (value) => setState(() => _notificationsEnabled = value),
    );
  }

  Widget _buildVersionInfo() {
    return ListTile(
      leading: const Icon(Icons.info_outline_rounded),
      title: const Text('App Version'),
      subtitle: Text(_appVersion),
    );
  }

  Widget _buildAdvancedSettings() {
    return Column(
      children: [
        const Divider(),
        ListTile(
          title: const Text('Privacy Policy'),
          trailing: const Icon(Icons.open_in_new_rounded),
          onTap: () {}, // Add navigation if needed.
        ),
        ListTile(
          title: const Text('Terms of Service'),
          trailing: const Icon(Icons.open_in_new_rounded),
          onTap: () {}, // Add navigation if needed.
        ),
      ],
    );
  }

  void _showLanguageSelector() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLanguageOption('English'),
            _buildLanguageOption('Spanish'),
            _buildLanguageOption('French'),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(String language) {
    return ListTile(
      title: Text(language),
      trailing: _selectedLanguage == language
          ? Icon(Icons.check_rounded,
              color: Theme.of(context).colorScheme.primary)
          : null,
      onTap: () {
        setState(() => _selectedLanguage = language);
        Navigator.pop(context);
      },
    );
  }
}
