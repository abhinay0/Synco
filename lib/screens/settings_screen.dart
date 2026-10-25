import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../services/app_updater_service.dart';
import '../services/native_ytdlp_bridge.dart';
import '../ui/components/frosted_container.dart';
import '../ui/theme/apple_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Engine settings
  bool _enableAria2c = false;
  bool _enableSponsorBlock = false;
  bool _preferH264 = true;

  String? _ytdlpVersion;
  bool _isUpdatingYtDlp = false;

  @override
  void initState() {
    super.initState();
    _loadEngineInfo();
  }

  Future<void> _loadEngineInfo() async {
    final v = await NativeYtDlpBridge.getYtDlpVersion();
    if (mounted) {
      setState(() => _ytdlpVersion = v);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final List<Color> appleAccentColors = [
      AppleTheme.systemBlue,
      AppleTheme.systemIndigo,
      AppleTheme.systemPurple,
      AppleTheme.systemPink,
      AppleTheme.systemOrange,
      AppleTheme.systemGreen,
      AppleTheme.systemTeal,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: AppleTheme.title2(
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Section: Engine & Performance (Matching Seal)
          _buildSectionHeader('ENGINE & PERFORMANCE'),
          FrostedContainer(
            borderRadius: 16,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  title: Text(
                    'Multi-Connection Acceleration',
                    style: AppleTheme.headline(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  subtitle: Text(
                    'Routes concurrent chunks for high-speed downloads (aria2c / -N 4)',
                    style: AppleTheme.caption(
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                  value: _enableAria2c,
                  onChanged: (val) {
                    HapticFeedback.selectionClick();
                    setState(() => _enableAria2c = val);
                  },
                ),
                _buildDivider(isDark),
                SwitchListTile.adaptive(
                  title: Text(
                    'Prefer H.264 Video Codec',
                    style: AppleTheme.headline(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  subtitle: Text(
                    'Maximum compatibility with QuickTime, TV, and mobile hardware decoders',
                    style: AppleTheme.caption(
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                  value: _preferH264,
                  onChanged: (val) {
                    HapticFeedback.selectionClick();
                    setState(() => _preferH264 = val);
                  },
                ),
                _buildDivider(isDark),
                SwitchListTile.adaptive(
                  title: Text(
                    'SponsorBlock Integration',
                    style: AppleTheme.headline(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  subtitle: Text(
                    'Automatically skip sponsored segments and video intros/outros',
                    style: AppleTheme.caption(
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                  value: _enableSponsorBlock,
                  onChanged: (val) {
                    HapticFeedback.selectionClick();
                    setState(() => _enableSponsorBlock = val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section: Storage
          _buildSectionHeader('DOWNLOAD DIRECTORY'),
          FrostedContainer(
            borderRadius: 16,
            padding: const EdgeInsets.all(12),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.folder_open_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              title: Text(
                'Destination Folder',
                style: AppleTheme.headline(
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              subtitle: Text(
                themeProvider.downloadPath ?? 'System Downloads Directory',
                style: AppleTheme.caption(
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                await HapticFeedback.lightImpact();
                if (!context.mounted) return;
                final controller = TextEditingController(
                  text: themeProvider.downloadPath ?? '',
                );
                final result = await showDialog<String>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Download Directory'),
                    content: TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        hintText: 'Enter absolute path...',
                        border: OutlineInputBorder(),
                      ),
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
              },
            ),
          ),
          const SizedBox(height: 20),

          // Section: Appearance
          _buildSectionHeader('APPEARANCE'),
          FrostedContainer(
            borderRadius: 16,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  title: Text(
                    'Dark Mode',
                    style: AppleTheme.headline(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  subtitle: Text(
                    'Pure black background with frosted glass chrome',
                    style: AppleTheme.caption(
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                  value: themeProvider.themeMode == ThemeMode.dark,
                  onChanged: (val) {
                    HapticFeedback.selectionClick();
                    themeProvider.toggleTheme(val);
                  },
                ),
                _buildDivider(isDark),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Accent Color',
                        style: AppleTheme.headline(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        children: appleAccentColors.map((color) {
                          final isSelected =
                              themeProvider.accentColor.toARGB32() ==
                              color.toARGB32();
                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              themeProvider.setAccentColor(color);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black,
                                        width: 2.5,
                                      )
                                    : null,
                                boxShadow: [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 20,
                                    )
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section: Updates & Engine Maintenance
          _buildSectionHeader('UPDATES & MAINTENANCE'),
          FrostedContainer(
            borderRadius: 16,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                Consumer<AppUpdaterService>(
                  builder: (context, updater, _) {
                    final info = updater.latestRelease;
                    final hasUpdate = info?.hasUpdate ?? false;

                    return ListTile(
                      leading: Icon(
                        Icons.system_update_rounded,
                        color: hasUpdate
                            ? AppleTheme.systemGreen
                            : Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(
                        'Synco App Version',
                        style: AppleTheme.headline(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      subtitle: Text(
                        hasUpdate
                            ? 'Update Available: v${info!.latestVersion} (Current: v${AppUpdaterService.currentAppVersion})'
                            : 'Version ${AppUpdaterService.currentAppVersion} (Latest)',
                        style: AppleTheme.caption(
                          color: hasUpdate
                              ? AppleTheme.systemGreen
                              : (isDark ? Colors.white60 : Colors.black54),
                        ),
                      ),
                      trailing: updater.isChecking
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : TextButton(
                              onPressed: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                await HapticFeedback.selectionClick();
                                final res = await updater.checkForUpdates();
                                if (!mounted) return;
                                if (res != null && res.hasUpdate) {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'New version v${res.latestVersion} is available!'),
                                      action: SnackBarAction(
                                        label: 'Update',
                                        onPressed: () =>
                                            updater.downloadAndInstallUpdate(),
                                      ),
                                    ),
                                  );
                                } else {
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text('Synco is up to date!'),
                                    ),
                                  );
                                }
                              },
                              child: Text(
                                  hasUpdate ? 'Update Now' : 'Check Updates'),
                            ),
                    );
                  },
                ),
                _buildDivider(isDark),
                ListTile(
                  leading: Icon(
                    Icons.terminal_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(
                    'yt-dlp Extractor Engine',
                    style: AppleTheme.headline(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  subtitle: Text(
                    _ytdlpVersion != null
                        ? 'Engine Version: $_ytdlpVersion'
                        : 'Bundled High-Speed Extractor',
                    style: AppleTheme.caption(
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                  trailing: _isUpdatingYtDlp
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : TextButton(
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            await HapticFeedback.selectionClick();
                            setState(() => _isUpdatingYtDlp = true);
                            final res =
                                await NativeYtDlpBridge.updateYtDlp();
                            final newVer =
                                await NativeYtDlpBridge.getYtDlpVersion();
                            if (!mounted) return;
                            setState(() {
                              _isUpdatingYtDlp = false;
                              if (newVer != null) _ytdlpVersion = newVer;
                            });
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  res != null
                                      ? 'Engine: ${res['status']} (${res['version']})'
                                      : 'Engine update checked',
                                ),
                              ),
                            );
                          },
                          child: const Text('Update Engine'),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section: About & Gold-Standard Reference
          _buildSectionHeader('ABOUT SYNCO V2'),
          FrostedContainer(
            borderRadius: 16,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.bolt_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Synco Media Suite v2.0',
                          style: AppleTheme.headline(
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        Text(
                          'Powered by Seal Architecture & Apple Fluid UX',
                          style: AppleTheme.caption(
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Synco v2 is engineered with the gold-standard architecture of Seal: multi-format sorters (-S), studio audio tagging, 1-tap clipboard detection, and reactive persistent queue management.',
                  style: AppleTheme.subheadline(
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title,
        style: AppleTheme.caption(color: Colors.grey).copyWith(
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      color: isDark ? Colors.white10 : Colors.black12,
    );
  }
}
