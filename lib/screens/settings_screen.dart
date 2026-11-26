import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:synco/providers/app_state_provider.dart';
import 'package:synco/services/api_service.dart';
import 'package:synco/utils/platform_utils.dart';
import 'package:synco/utils/theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _resolvedDefaultDir = '';
  bool _isUpdatingEngine = false;

  @override
  void initState() {
    super.initState();
    unawaited(_initData());
  }

  Future<void> _initData() async {
    final defaultDir = await PlatformUtils.resolveDefaultDownloadDirectory();
    if (!mounted) return;
    setState(() => _resolvedDefaultDir = defaultDir);
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    if (appState.diagnostics == null) {
      await appState.refreshDiagnostics();
    }
  }

  Future<void> _editTextSetting({
    required String title,
    required String initialValue,
    required String hint,
    String? helperText,
    required ValueChanged<String> onSave,
  }) async {
    final controller = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(hintText: hint),
            ),
            if (helperText != null) ...[
              const SizedBox(height: 10),
              Text(
                helperText,
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: Theme.of(ctx)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.65),
                    ),
              ),
            ],
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
    controller.dispose();
    if (result != null) {
      onSave(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    final theme = Theme.of(context);
    final diag = appState.diagnostics;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
            children: [
              // Engine Health & YouTube EJS/SABR Diagnostics
              _buildSectionHeader(context, 'Engine & YouTube Compatibility'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.memory_rounded,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Platform Engine (${PlatformUtils.platformName})',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Re-check engine status',
                            onPressed: appState.isCheckingDiagnostics
                                ? null
                                : () => appState.refreshDiagnostics(),
                            icon: appState.isCheckingDiagnostics
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.refresh_rounded, size: 20),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (diag != null) ...[
                        _buildDiagRow(
                          context,
                          label: PlatformUtils.isDesktop
                              ? 'yt-dlp Engine'
                              : 'Extractor Engine',
                          value: diag.ytDlpVersion,
                          ok: diag.ytDlpAvailable,
                        ),
                        if (PlatformUtils.isDesktop) ...[
                          const SizedBox(height: 8),
                          _buildDiagRow(
                            context,
                            label: 'FFmpeg (MP4 Merge / MP3)',
                            value: diag.ffmpegAvailable
                                ? 'Installed'
                                : 'Missing (needed for 1080p+ & MP3)',
                            ok: diag.ffmpegAvailable,
                          ),
                          const SizedBox(height: 8),
                          _buildDiagRow(
                            context,
                            label: 'JS Runtime (YouTube EJS)',
                            value: diag.hasJsRuntime
                                ? '${diag.jsRuntimeName} (${diag.jsRuntimePath})'
                                : 'Missing — install Deno or Node.js',
                            ok: diag.hasJsRuntime,
                          ),
                        ],
                        const SizedBox(height: 8),
                        _buildDiagRow(
                          context,
                          label: 'Synco Backend API',
                          value: diag.backendReachable
                              ? 'Connected (${appState.backendUrl})'
                              : 'Offline (${appState.backendUrl})',
                          ok: diag.backendReachable,
                        ),
                      ] else
                        const LinearProgressIndicator(),
                      if (PlatformUtils.isDesktop) ...[
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            FilledButton.tonalIcon(
                              onPressed: _isUpdatingEngine
                                  ? null
                                  : () async {
                                      setState(() => _isUpdatingEngine = true);
                                      final msg =
                                          await appState.runEngineUpdate();
                                      if (!context.mounted) return;
                                      setState(() => _isUpdatingEngine = false);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(content: Text(msg)),
                                      );
                                    },
                              icon: _isUpdatingEngine
                                  ? const SizedBox(
                                      width: 15,
                                      height: 15,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.system_update_alt_rounded,
                                      size: 18,
                                    ),
                              label: const Text('Update yt-dlp'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              Card(
                child: Column(
                  children: [
                    if (PlatformUtils.isDesktop) ...[
                      ListTile(
                        leading: const Icon(Icons.cookie_outlined),
                        title: const Text('Browser Cookies (Anti-Bot / Age-Gate)'),
                        subtitle: Text(
                          appState.cookiesBrowser == 'none'
                              ? 'Disabled (use if YouTube asks to sign in)'
                              : 'Using cookies from ${appState.cookiesBrowser}',
                        ),
                        trailing: DropdownButton<String>(
                          value: appState.cookiesBrowser,
                          underline: const SizedBox.shrink(),
                          items: const [
                            DropdownMenuItem(value: 'none', child: Text('None')),
                            DropdownMenuItem(
                              value: 'chrome',
                              child: Text('Chrome'),
                            ),
                            DropdownMenuItem(
                              value: 'firefox',
                              child: Text('Firefox'),
                            ),
                            DropdownMenuItem(
                              value: 'safari',
                              child: Text('Safari'),
                            ),
                            DropdownMenuItem(value: 'edge', child: Text('Edge')),
                            DropdownMenuItem(
                              value: 'brave',
                              child: Text('Brave'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) appState.setCookiesBrowser(v);
                          },
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.description_outlined),
                        title: const Text('Custom cookies.txt Path'),
                        subtitle: Text(
                          appState.cookiesFilePath.isEmpty
                              ? 'Optional — overrides browser cookies if set'
                              : appState.cookiesFilePath,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _editTextSetting(
                          title: 'cookies.txt File Path',
                          initialValue: appState.cookiesFilePath,
                          hint: '/path/to/cookies.txt',
                          helperText:
                              'Leave blank to disable. Useful for restricted playlists or SABR-blocked sessions.',
                          onSave: appState.setCookiesFilePath,
                        ),
                      ),
                      const Divider(height: 1),
                    ],
                    ListTile(
                      leading: const Icon(Icons.cloud_outlined),
                      title: const Text('Backend Server URL'),
                      subtitle: Text(
                        appState.backendUrl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: TextButton(
                        onPressed: () async {
                          final ok = await ApiService.checkHealth(
                            appState.backendUrl,
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                ok
                                    ? 'Backend server is online!'
                                    : 'Could not reach ${appState.backendUrl}',
                              ),
                            ),
                          );
                          await appState.refreshDiagnostics();
                        },
                        child: const Text('Test'),
                      ),
                      onTap: () => _editTextSetting(
                        title: 'Synco Backend URL',
                        initialValue: appState.backendUrl,
                        hint: 'https://your-synco-server.example.com',
                        helperText:
                            'Used on Web and for non-YouTube sites (Instagram, TikTok, Reddit, SoundCloud) on Mobile.',
                        onSave: appState.setBackendUrl,
                      ),
                    ),
                  ],
                ),
              ),

              // Storage & Download Defaults
              _buildSectionHeader(context, 'Downloads & Storage'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.folder_open_rounded),
                      title: const Text('Download Location'),
                      subtitle: Text(
                        appState.downloadPath ??
                            (_resolvedDefaultDir.isNotEmpty
                                ? '$_resolvedDefaultDir (Default)'
                                : 'System Downloads'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: PlatformUtils.useBackendAPI
                          ? null
                          : () => _editTextSetting(
                                title: 'Download Folder Path',
                                initialValue: appState.downloadPath ??
                                    _resolvedDefaultDir,
                                hint: _resolvedDefaultDir,
                                helperText:
                                    'Synco creates a "Synco" folder inside this path. Leave empty to reset to platform default.',
                                onSave: appState.setDownloadPath,
                              ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.hd_outlined),
                      title: const Text('Default Video Quality'),
                      trailing: DropdownButton<String>(
                        value: appState.defaultVideoQuality,
                        underline: const SizedBox.shrink(),
                        items: const [
                          DropdownMenuItem(value: 'Best', child: Text('Best')),
                          DropdownMenuItem(
                            value: '2160p',
                            child: Text('4K (2160p)'),
                          ),
                          DropdownMenuItem(
                            value: '1440p',
                            child: Text('1440p'),
                          ),
                          DropdownMenuItem(
                            value: '1080p',
                            child: Text('1080p'),
                          ),
                          DropdownMenuItem(value: '720p', child: Text('720p')),
                          DropdownMenuItem(value: '480p', child: Text('480p')),
                        ],
                        onChanged: (v) {
                          if (v != null) appState.setDefaultVideoQuality(v);
                        },
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.music_note_rounded),
                      title: const Text('Default Audio Format'),
                      trailing: DropdownButton<String>(
                        value: appState.defaultAudioFormat,
                        underline: const SizedBox.shrink(),
                        items: const [
                          DropdownMenuItem(value: 'mp3', child: Text('MP3')),
                          DropdownMenuItem(value: 'm4a', child: Text('M4A')),
                          DropdownMenuItem(value: 'opus', child: Text('OPUS')),
                          DropdownMenuItem(value: 'wav', child: Text('WAV')),
                        ],
                        onChanged: (v) {
                          if (v != null) appState.setDefaultAudioFormat(v);
                        },
                      ),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      secondary: const Icon(Icons.content_paste_go_rounded),
                      title: const Text('Auto-detect Clipboard Links'),
                      subtitle: const Text(
                        'Show quick download banner for copied media URLs',
                      ),
                      value: appState.autoDetectClipboard,
                      onChanged: appState.toggleAutoDetectClipboard,
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      secondary: const Icon(Icons.create_new_folder_outlined),
                      title: const Text('Organize Playlists & Channels'),
                      subtitle: const Text(
                        'Save playlists and channels in dedicated subfolders',
                      ),
                      value: appState.autoCreateSubfolders,
                      onChanged: appState.toggleAutoCreateSubfolders,
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      secondary: const Icon(Icons.album_outlined),
                      title: const Text('Embed Metadata & Cover Art'),
                      subtitle: const Text(
                        'Attach title, artist, and thumbnail tags to downloads',
                      ),
                      value: appState.embedMetadata,
                      onChanged: appState.toggleEmbedMetadata,
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      secondary: const Icon(Icons.history_toggle_off_rounded),
                      title: const Text('Incognito Mode'),
                      subtitle: const Text('Do not record download history'),
                      value: appState.incognitoMode,
                      onChanged: appState.toggleIncognito,
                    ),
                  ],
                ),
              ),

              // Appearance
              _buildSectionHeader(context, 'Appearance'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Theme Mode',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<ThemeMode>(
                          segments: const [
                            ButtonSegment(
                              value: ThemeMode.dark,
                              icon: Icon(Icons.dark_mode_rounded, size: 17),
                              label: Text('Dark'),
                            ),
                            ButtonSegment(
                              value: ThemeMode.light,
                              icon: Icon(Icons.light_mode_rounded, size: 17),
                              label: Text('Light'),
                            ),
                            ButtonSegment(
                              value: ThemeMode.system,
                              icon: Icon(Icons.brightness_auto_rounded, size: 17),
                              label: Text('System'),
                            ),
                          ],
                          selected: {appState.themeMode},
                          onSelectionChanged: (s) =>
                              appState.setThemeMode(s.first),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Accent Color',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 12,
                        runSpacing: 10,
                        children: SyncoTheme.accentPresets.map((color) {
                          final isSelected =
                              appState.accentColor.toARGB32() ==
                                  color.toARGB32();
                          return GestureDetector(
                            onTap: () => appState.setAccentColor(color),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(
                                        color: theme.colorScheme.onSurface,
                                        width: 3,
                                      )
                                    : null,
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check_rounded,
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
              ),

              // About
              _buildSectionHeader(context, 'About'),
              const Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.info_outline_rounded),
                      title: Text('Synco'),
                      subtitle: Text(
                        'Universal Video, Music, Playlist & Channel Downloader',
                      ),
                      trailing: Text('v2.0.0'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDiagRow(
    BuildContext context, {
    required String label,
    required String value,
    required bool ok,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          ok ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
          size: 16,
          color: ok ? const Color(0xFF22C55E) : Colors.amber,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
      ),
    );
  }
}
