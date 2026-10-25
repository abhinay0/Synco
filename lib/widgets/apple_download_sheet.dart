import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../engine/argument_builder.dart';
import '../engine/quality_presets.dart';
import '../models/download_models.dart';
import '../ui/components/frosted_container.dart';
import '../ui/components/segmented_pill.dart';
import '../ui/theme/apple_theme.dart';

class AppleDownloadSheet extends StatefulWidget {
  final VideoInfo? videoInfo;
  final PlaylistInfo? playlistInfo;
  final String url;

  const AppleDownloadSheet({
    super.key,
    this.videoInfo,
    this.playlistInfo,
    required this.url,
  });

  @override
  State<AppleDownloadSheet> createState() => _AppleDownloadSheetState();
}

class _AppleDownloadSheetState extends State<AppleDownloadSheet> {
  // Mode: 0 = Video, 1 = Audio
  int _mediaMode = 0;

  // Selected preset
  PresetType _selectedPreset = PresetType.bestForPhone;

  // Custom configurations
  String _customResolution = '1080';
  String _customAudioFormat = 'mp3';
  bool _embedSubtitles = false;
  bool _enableSponsorBlock = false;

  // Playlist selection
  final Set<int> _selectedPlaylistIndices = {};

  @override
  void initState() {
    super.initState();
    if (widget.playlistInfo != null) {
      _selectedPlaylistIndices.addAll(
        List.generate(widget.playlistInfo!.entries.length, (i) => i + 1),
      );
    }
  }

  void _onPresetSelected(QualityPreset preset) {
    setState(() {
      _selectedPreset = preset.type;
      _mediaMode = preset.isAudioOnly ? 1 : 0;
      if (preset.preferredResolution != null) {
        _customResolution = preset.preferredResolution!;
      }
      if (preset.preferredAudioCodec != null) {
        _customAudioFormat = preset.preferredAudioCodec!;
      }
    });
  }

  void _confirmDownload() {
    HapticFeedback.mediumImpact();

    final isAudio = _mediaMode == 1;
    final preset = QualityPreset.fromType(_selectedPreset);

    final options = DownloadOptions(
      isAudioOnly: isAudio,
      audioFormat: isAudio ? _customAudioFormat : null,
      resolution: !isAudio ? _customResolution : null,
      preset: _selectedPreset != PresetType.custom ? preset : null,
      embedMetadata: true,
      embedThumbnail: true,
      cropArtwork: isAudio,
      embedSubtitles: _embedSubtitles,
      enableSponsorBlock: _enableSponsorBlock,
      playlistIndices: widget.playlistInfo != null
          ? _selectedPlaylistIndices.toList()
          : null,
    );

    Navigator.of(context).pop(options);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = widget.videoInfo?.title ?? widget.playlistInfo?.title ?? widget.url;
    final uploader = widget.videoInfo?.uploader ?? widget.playlistInfo?.uploader ?? '';
    final thumbnail = widget.videoInfo?.thumbnail ?? widget.playlistInfo?.thumbnail ?? '';
    final duration = widget.videoInfo?.duration ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header / Media Preview Info
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 84,
                  height: 60,
                  color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                  child: thumbnail.isNotEmpty
                      ? Image.network(
                          thumbnail,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Padding(
                            padding: const EdgeInsets.all(10),
                            child: Image.asset(
                              'assets/icon/app_icon.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.all(10),
                          child: Image.asset(
                            'assets/icon/app_icon.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppleTheme.headline(
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (uploader.isNotEmpty)
                          Expanded(
                            child: Text(
                              uploader,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppleTheme.caption(
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ),
                        if (duration.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.black.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              duration,
                              style: AppleTheme.caption(
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Video vs Audio Segmented Pill
          AppleSegmentedPill<int>(
            values: const [0, 1],
            labels: const ['Video', 'Audio Only'],
            icons: const [Icons.videocam_rounded, Icons.headphones_rounded],
            selectedValue: _mediaMode,
            onValueChanged: (val) {
              setState(() {
                _mediaMode = val;
                if (val == 1 && _selectedPreset != PresetType.highestAudio) {
                  _selectedPreset = PresetType.highestAudio;
                } else if (val == 0 && _selectedPreset == PresetType.highestAudio) {
                  _selectedPreset = PresetType.bestForPhone;
                }
              });
            },
          ),
          const SizedBox(height: 16),

          // Smart Quality Presets
          Text(
            'Smart Quality Presets',
            style: AppleTheme.subheadline(
              color: isDark ? Colors.white70 : Colors.black54,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),

          // Presets Grid
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: QualityPreset.all.map((preset) {
              final isSelected = _selectedPreset == preset.type;
              return GestureDetector(
                onTap: () => _onPresetSelected(preset),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.18)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.04)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        preset.icon,
                        size: 16,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : (isDark ? Colors.white70 : Colors.black54),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        preset.title,
                        style: AppleTheme.subheadline(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : (isDark ? Colors.white : Colors.black),
                        ).copyWith(
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),

          // Advanced Options (Subtitles, SponsorBlock)
          FrostedContainer(
            borderRadius: 14,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Embed Subtitles',
                    style: AppleTheme.body(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  subtitle: Text(
                    'Downloads and bakes official or auto-generated subs',
                    style: AppleTheme.caption(
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                  value: _embedSubtitles,
                  onChanged: (val) {
                    HapticFeedback.selectionClick();
                    setState(() => _embedSubtitles = val);
                  },
                ),
                Divider(
                  height: 1,
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'SponsorBlock',
                    style: AppleTheme.body(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  subtitle: Text(
                    'Automatically skip sponsors, intros, and self-promotion',
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

          // Start Download CTA Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _confirmDownload,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.arrow_downward_rounded, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Start Download',
                    style: AppleTheme.headline(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
