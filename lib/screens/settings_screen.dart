import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

    // Check if we're on desktop (where file picker works)
    final bool isDesktop =
        !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), centerTitle: false),
      body: ListView(
        children: [
          _buildSectionHeader(context, 'General'),
          _buildSettingTile(
            context,
            icon: Icons.folder_open_rounded,
            title: 'Download Location',
            subtitle:
                themeProvider.downloadPath ??
                (isDesktop ? 'Downloads' : '/storage/emulated/0/Download'),
            onTap: () async {
              if (isDesktop) {
                // Desktop: Show message (file_picker was removed)
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Folder picker temporarily unavailable on desktop',
                    ),
                  ),
                );
              } else {
                // Mobile: Show dialog to enter custom path
                final controller = TextEditingController(
                  text:
                      themeProvider.downloadPath ??
                      '/storage/emulated/0/Download',
                );

                final result = await showDialog<String>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Download Location'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Enter download folder path:'),
                        const SizedBox(height: 12),
                        TextField(
                          controller: controller,
                          decoration: const InputDecoration(
                            hintText: '/storage/emulated/0/Download',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Common paths:\n'
                          '• /storage/emulated/0/Download\n'
                          '• /storage/emulated/0/Movies\n'
                          '• /storage/emulated/0/DCIM',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, controller.text),
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                );

                if (result != null && result.isNotEmpty) {
                  themeProvider.setDownloadPath(result);
                }
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
