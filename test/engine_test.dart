import 'package:flutter_test/flutter_test.dart';
import 'package:synco/engine/argument_builder.dart';
import 'package:synco/engine/download_task.dart';
import 'package:synco/engine/format_sorter.dart';
import 'package:synco/engine/quality_presets.dart';
import 'package:synco/services/clipboard_service.dart';

void main() {
  group('Quality Presets & Format Sorter', () {
    test('bestForPhone has correct resolution and h264/aac sorter', () {
      const preset = QualityPreset.bestForPhone;
      expect(preset.isAudioOnly, false);
      expect(preset.preferredResolution, '1080');
      expect(preset.formatSorter, contains('vcodec:h264'));
      expect(preset.formatSorter, contains('acodec:aac'));
    });

    test('highestAudio has opus and high bitrate sorter', () {
      const preset = QualityPreset.highestAudio;
      expect(preset.isAudioOnly, true);
      expect(preset.formatSorter, contains('acodec:opus'));
      expect(preset.formatSorter, contains('abr~320'));
    });

    test('FormatSorter builds valid sorter strings', () {
      final videoSorter = FormatSorter.buildSorter(
        resolution: '1080p',
        preferCompatibility: true,
        isAudioOnly: false,
      );
      expect(videoSorter, 'res:1080,proto,vcodec:h264,acodec:aac,ext');

      final audioSorter = FormatSorter.buildSorter(
        isAudioOnly: true,
        audioFormat: 'm4a',
      );
      expect(audioSorter, 'acodec:aac,abr~256');
    });
  });

  group('DynamicArgumentBuilder', () {
    test('builds info arguments with single json and no playlist', () {
      final args = DynamicArgumentBuilder.buildInfoArguments(
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      );
      expect(args, contains('--dump-single-json'));
      expect(args, contains('--no-playlist'));
    });

    test('builds audio extraction arguments with studio metadata and crop', () {
      final args = DynamicArgumentBuilder.buildDownloadArguments(
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        '/tmp/downloads',
        const DownloadOptions(
          isAudioOnly: true,
          audioFormat: 'mp3',
          embedMetadata: true,
          cropArtwork: true,
        ),
      );

      expect(args, contains('-x'));
      expect(args, contains('--audio-format'));
      expect(args, contains('mp3'));
      expect(args, contains('--embed-metadata'));
      expect(args, contains('--embed-thumbnail'));
      expect(args, contains('--ppa'));
      expect(args, contains(DynamicArgumentBuilder.cropArtworkCommand));
    });

    test('builds video arguments with multi-connection acceleration', () {
      final args = DynamicArgumentBuilder.buildDownloadArguments(
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        '/tmp/downloads',
        const DownloadOptions(
          isAudioOnly: false,
          resolution: '1080',
          concurrentFragments: 4,
          enableSponsorBlock: true,
        ),
      );

      expect(args, contains('-N'));
      expect(args, contains('4'));
      expect(args, contains('--remux-video'));
      expect(args, contains('mp4'));
      expect(args, contains('--sponsorblock-remove'));
      expect(args, contains('sponsor,intro,outro'));
    });
  });

  group('ClipboardDetector', () {
    test('detects supported video domains', () {
      final urls = [
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        'https://youtu.be/dQw4w9WgXcQ',
        'https://www.instagram.com/reel/C3b...',
        'https://www.instagram.com/p/DFxyz123/',
        'https://www.tiktok.com/@user/video/12345',
        'https://twitter.com/user/status/12345',
        'https://x.com/user/status/12345',
        'https://www.facebook.com/watch/?v=12345',
        'https://fb.watch/xyz123/',
        'https://www.reddit.com/r/funny/comments/12345/video/',
        'https://soundcloud.com/artist/track',
        'https://vimeo.com/12345678',
        'https://www.twitch.tv/videos/12345',
      ];

      for (var url in urls) {
        final matches = ClipboardDetector.isRecognizedMediaUrl(url);
        expect(matches, true, reason: 'Failed for $url');
      }
    });

    test('recognizes any valid media web URL', () {
      expect(ClipboardDetector.isRecognizedMediaUrl('https://example.com/stream.mp4'), true);
      expect(ClipboardDetector.isRecognizedMediaUrl('http://myvideohost.org/video/99'), true);
      expect(ClipboardDetector.isRecognizedMediaUrl('not-a-url'), false);
      expect(ClipboardDetector.isRecognizedMediaUrl(''), false);
    });

    test('ignores non-media links', () {
      final invalidUrls = [
        'https://google.com',
        'https://github.com/JunkFood02/Seal',
        'just some text',
      ];

      for (var url in invalidUrls) {
        final matches = ClipboardDetector.supportedPatterns
            .any((pattern) => pattern.hasMatch(url));
        expect(matches, false, reason: 'Should not match $url');
      }
    });
  });

  group('DownloadTask Serialization', () {
    test('serializes and deserializes task state cleanly', () {
      final task = DownloadTask(
        id: 'test_123',
        url: 'https://youtu.be/test',
        title: 'Rick Astley - Never Gonna Give You Up',
        uploader: 'RickAstleyVEVO',
        thumbnailUrl: 'https://i.ytimg.com/vi/test/hqdefault.jpg',
        duration: '3:33',
        options: const DownloadOptions(isAudioOnly: true, audioFormat: 'opus'),
      );

      final json = task.toJson();
      expect(json['id'], 'test_123');
      expect(json['title'], 'Rick Astley - Never Gonna Give You Up');
      expect(json['isAudioOnly'], true);
      expect(json['audioFormat'], 'opus');

      final reconstructed = DownloadTask.fromJson(json);
      expect(reconstructed.id, 'test_123');
      expect(reconstructed.title, 'Rick Astley - Never Gonna Give You Up');
      expect(reconstructed.options.isAudioOnly, true);
      expect(reconstructed.options.audioFormat, 'opus');
    });
  });
}
