import 'dart:io';
import 'package:flutter/foundation.dart';
import 'format_sorter.dart';
import 'quality_presets.dart';

/// Configuration options for downloading media mirroring Seal's DownloadPreferences
class DownloadOptions {
  final bool isAudioOnly;
  final String? audioFormat; // 'mp3', 'm4a', 'opus', 'flac'
  final String? resolution; // '1080', '720', etc.
  final QualityPreset? preset;
  final String? formatId;
  final bool embedThumbnail;
  final bool embedMetadata;
  final bool cropArtwork;
  final bool embedSubtitles;
  final bool autoSubtitles;
  final String? subtitleLanguage;
  final String? convertSubtitles; // 'srt', 'vtt', 'ass'
  final bool enableSponsorBlock;
  final String sponsorBlockCategories; // 'sponsor,intro,outro'
  final int concurrentFragments; // e.g. 4 for multi-connection acceleration
  final bool useAria2c;
  final String? cookiesPath;
  final String? proxyUrl;
  final bool forceIpv4;
  final bool restrictFilenames;
  final List<int>? playlistIndices;
  final bool splitByChapter;

  const DownloadOptions({
    this.isAudioOnly = false,
    this.audioFormat = 'mp3',
    this.resolution = '1080',
    this.preset,
    this.formatId,
    this.embedThumbnail = true,
    this.embedMetadata = true,
    this.cropArtwork = true,
    this.embedSubtitles = false,
    this.autoSubtitles = false,
    this.subtitleLanguage = 'en.*,en',
    this.convertSubtitles = 'srt',
    this.enableSponsorBlock = false,
    this.sponsorBlockCategories = 'sponsor,intro,outro',
    this.concurrentFragments = 4,
    this.useAria2c = false,
    this.cookiesPath,
    this.proxyUrl,
    this.forceIpv4 = false,
    this.restrictFilenames = false,
    this.playlistIndices,
    this.splitByChapter = false,
  });

  factory DownloadOptions.fromPreset(QualityPreset preset, {
    String? cookiesPath,
    bool enableSponsorBlock = false,
    bool embedSubtitles = false,
  }) {
    return DownloadOptions(
      isAudioOnly: preset.isAudioOnly,
      audioFormat: preset.preferredAudioCodec ?? 'mp3',
      resolution: preset.preferredResolution,
      preset: preset,
      embedThumbnail: true,
      embedMetadata: true,
      cropArtwork: preset.isAudioOnly,
      enableSponsorBlock: enableSponsorBlock,
      embedSubtitles: embedSubtitles,
      cookiesPath: cookiesPath,
    );
  }
}

/// Dynamic CLI argument builder mirroring Seal's DownloadUtil
class DynamicArgumentBuilder {
  static const String defaultBasename = '%(title).200B';
  static const String defaultOutputTemplate = '%(title).200B.%(ext)s';
  static const String chapterOutputTemplate =
      'chapter:%(title).200B/%(section_number)d - %(section_title).200B.%(ext)s';

  static const String cropArtworkCommand =
      "ffmpeg: -c:v mjpeg -vf crop=\"'if(gt(ih,iw),iw,ih)':'if(gt(iw,ih),ih,iw)'\"";

  /// Build yt-dlp arguments for fetching video or playlist metadata
  static List<String> buildInfoArguments(
    String url, {
    bool isPlaylist = false,
    String? cookiesPath,
    String? proxyUrl,
  }) {
    final List<String> args = [
      url,
      '--dump-single-json',
      '-o',
      defaultBasename,
      '--socket-timeout',
      '10',
      '-R',
      '2',
      '--no-warnings',
    ];

    if (isPlaylist) {
      args.add('--flat-playlist');
    } else {
      args.add('--no-playlist');
    }

    if (cookiesPath != null && cookiesPath.isNotEmpty) {
      args.addAll(['--cookies', cookiesPath]);
    }

    if (proxyUrl != null && proxyUrl.isNotEmpty) {
      args.addAll(['--proxy', proxyUrl]);
    }

    return args;
  }

  /// Build yt-dlp arguments for downloading with all options applied
  static List<String> buildDownloadArguments(
    String url,
    String outputDirectory,
    DownloadOptions options,
  ) {
    final List<String> args = [
      url,
      '--no-mtime',
      '--socket-timeout',
      '15',
      '-R',
      '3',
      '--newline', // ensures line-buffered progress for regex parsing
      '-P',
      outputDirectory,
    ];

    // Output template
    if (options.splitByChapter) {
      args.addAll(['-o', chapterOutputTemplate, '--split-chapters']);
    } else {
      args.addAll(['-o', defaultOutputTemplate]);
    }

    // Filename restriction
    if (options.restrictFilenames) {
      args.add('--restrict-filenames');
    }

    // Network options
    if (options.forceIpv4) {
      args.add('-4');
    }
    final proxy = options.proxyUrl;
    if (proxy != null && proxy.isNotEmpty) {
      args.addAll(['--proxy', proxy]);
    }
    final cookies = options.cookiesPath;
    if (cookies != null && cookies.isNotEmpty) {
      args.addAll(['--cookies', cookies]);
    }

    // Acceleration: aria2c or concurrent fragments
    if (options.useAria2c) {
      final downloaderBin =
          (!kIsWeb && Platform.isAndroid) ? 'libaria2c.so' : 'aria2c';
      args.addAll([
        '--downloader',
        downloaderBin,
        '--downloader-args',
        'aria2c:-x 8 -s 8 -k 1M -j 4',
      ]);
    } else if (options.concurrentFragments > 1) {
      args.addAll(['-N', options.concurrentFragments.toString()]);
    }

    // Playlist options
    if (options.playlistIndices != null && options.playlistIndices!.isNotEmpty) {
      args.addAll(['--playlist-items', options.playlistIndices!.join(',')]);
    } else {
      args.add('--no-playlist');
    }

    // SponsorBlock integration
    if (options.enableSponsorBlock) {
      args.addAll(['--sponsorblock-remove', options.sponsorBlockCategories]);
    }

    // Format selection & Audio Extraction
    if (options.isAudioOnly) {
      args.add('-x');
      final fmt = options.audioFormat ?? 'mp3';
      args.addAll(['--audio-format', fmt]);
      args.addAll(['--audio-quality', '0']); // 0 is best in yt-dlp

      // Sorter or format id
      if (options.formatId != null && options.formatId!.isNotEmpty) {
        args.addAll(['-f', options.formatId!]);
      } else if (options.preset != null) {
        args.addAll(['-S', options.preset!.formatSorter]);
      } else {
        final sorter = FormatSorter.buildSorter(
          isAudioOnly: true,
          audioFormat: fmt,
        );
        args.addAll(['-S', sorter]);
      }

      // Audio Metadata & Album Art
      if (options.embedMetadata) {
        args.addAll([
          '--embed-metadata',
          '--embed-thumbnail',
          '--convert-thumbnails',
          'jpg',
          '--parse-metadata',
          '%(release_year,upload_date)s:%(meta_date)s',
          '--parse-metadata',
          '%(album,title)s:%(meta_album)s',
          '--parse-metadata',
          '%(uploader,channel)s:%(meta_artist)s',
        ]);

        if (options.cropArtwork) {
          args.addAll(['--ppa', cropArtworkCommand]);
        }
      }
    } else {
      // Video options
      if (options.formatId != null && options.formatId!.isNotEmpty) {
        args.addAll(['-f', options.formatId!]);
      } else if (options.preset != null) {
        args.addAll(['-S', options.preset!.formatSorter]);
      } else {
        final sorter = FormatSorter.buildSorter(
          resolution: options.resolution,
          preferCompatibility: true,
          isAudioOnly: false,
        );
        args.addAll(['-S', sorter]);
      }

      // Remux to mp4 by default for universal player support
      args.addAll(['--remux-video', 'mp4']);

      // Metadata & thumbnail
      if (options.embedMetadata) {
        args.add('--add-metadata');
        args.add('--embed-chapters');
      }
      if (options.embedThumbnail) {
        args.add('--embed-thumbnail');
      }

      // Subtitles
      if (options.embedSubtitles) {
        args.add('--embed-subs');
        if (options.autoSubtitles) {
          args.add('--write-auto-subs');
        }
        if (options.subtitleLanguage != null) {
          args.addAll(['--sub-langs', options.subtitleLanguage!]);
        }
        if (options.convertSubtitles != null) {
          args.addAll(['--convert-subs', options.convertSubtitles!]);
        }
      }
    }

    return args;
  }
}
