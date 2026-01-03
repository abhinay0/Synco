import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:synco/main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    // Color options
    final List<Color> accentColors = [
      const Color(0xFFA4D96C), // Lime (Default)
      const Color(0xFF6366F1), // Indigo
      const Color(0xFF06B6D4), // Cyan
      const Color(0xFFFF9F1C), // Orange
      const Color(0xFFE91E63), // Pink
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), centerTitle: false),
      body: ListView(
        children: [
          _buildSectionHeader(context, 'General'),
          _buildSettingTile(
            context,
            icon: Icons.folder_open_rounded,
            title: 'Download Location',
            subtitle: themeProvider.downloadPath ?? 'Downloads',
            onTap: () async {
              String? selectedDirectory = await FilePicker.platform
                  .getDirectoryPath();
              if (selectedDirectory != null) {
                themeProvider.setDownloadPath(selectedDirectory);
              }
            },
          ),
          SwitchListTile(
            title: const Text('Incognito Mode'),
            subtitle: const Text('Do not save download history'),
            value: themeProvider.incognitoMode,
            onChanged: (bool value) {
              themeProvider.toggleIncognito(value);
            },
            secondary: const Icon(Icons.history_toggle_off_rounded),
          ),

          const Divider(),
          _buildSectionHeader(context, 'Appearance'),

          SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: const Text('Use dark theme'),
            value: themeProvider.themeMode == ThemeMode.dark,
            onChanged: (bool value) {
              themeProvider.toggleTheme(value);
            },
            secondary: const Icon(Icons.dark_mode_rounded),
          ),

          ListTile(
            title: const Text('Accent Color'),
            subtitle: const Text('Customize app buttons and highlights'),
            leading: const Icon(Icons.palette_rounded),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Wrap(
              spacing: 12,
              children: accentColors.map((color) {
                final isSelected =
                    themeProvider.accentColor.toARGB32() == color.toARGB32();
                return GestureDetector(
                  onTap: () => themeProvider.setAccentColor(color),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(
                              color: Theme.of(context).colorScheme.onSurface,
                              width: 3,
                            )
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ),

          const Divider(),
          _buildSectionHeader(context, 'About'),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: const Text('Version'),
            trailing: const Text('1.0.0-alpha'),
          ),
          ListTile(
            leading: const Icon(Icons.code_rounded),
            title: const Text('Open Source'),
            subtitle: const Text('Synco is free and open source software'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildSettingTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
