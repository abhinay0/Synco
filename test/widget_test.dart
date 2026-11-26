import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synco/main.dart';
import 'package:synco/models/download_models.dart';
import 'package:synco/providers/app_state_provider.dart';
import 'package:synco/services/url_resolver_service.dart';

void main() {
  group('UrlResolverService', () {
    test('extracts clean URL and track hint from Amazon Music share text', () {
      const shareText =
          "Check out T.I.A. [Explicit] by K'naan on Amazon Music\n"
          'https://music.amazon.in/albums/B073HWBHPD?trackAsin=B073N3FFK8&do=play';

      final parsed = UrlResolverService.parseInput(
        shareText,
        preferredMode: AppMediaMode.music,
      );

      expect(parsed.isValid, isTrue);
      expect(parsed.platform, MediaSourcePlatform.amazonMusic);
      expect(parsed.contentType, MediaContentType.audio);
      expect(
        parsed.cleanUrl,
        'https://music.amazon.in/albums/B073HWBHPD?trackAsin=B073N3FFK8&do=play',
      );
      expect(parsed.searchHint, "T.I.A. K'naan");
      expect(parsed.requiresMusicSearchResolution, isTrue);
    });

    test('detects YouTube channel, playlist, and video URLs accurately', () {
      final channel = UrlResolverService.parseInput(
        'https://www.youtube.com/@mkbhd/videos',
      );
      expect(channel.platform, MediaSourcePlatform.youtube);
      expect(channel.contentType, MediaContentType.channel);

      final playlist = UrlResolverService.parseInput(
        'https://www.youtube.com/playlist?list=PL1234567890',
      );
      expect(playlist.platform, MediaSourcePlatform.youtube);
      expect(playlist.contentType, MediaContentType.playlist);

      final video = UrlResolverService.parseInput(
        'https://youtu.be/zLDTpP0-P3U',
      );
      expect(video.platform, MediaSourcePlatform.youtube);
      expect(video.contentType, MediaContentType.video);
    });

    test('formats YouTube EJS and SABR raw stderr into concise summary', () {
      const rawYtDlpError =
          'WARNING: [youtube] zLDTpP0-P3U: Some ios client https formats have been skipped.\n'
          'YouTube may have enabled the SABR-only streaming experiment.\n'
          'WARNING: [youtube] zLDTpP0-P3U: n challenge solving failed: Some formats may be missing.\n'
          'For more details, refer to https://github.com/yt-dlp/yt-dlp/wiki/EJS\n'
          'ERROR: [youtube] zLDTpP0-P3U: Requested format is not available.';

      final friendly = UrlResolverService.formatFriendlyError(rawYtDlpError);
      expect(friendly.summary.length, lessThan(120));
      expect(friendly.summary.toLowerCase(), contains('js challenge'));
      expect(friendly.isEngineFixable, isTrue);
      expect(friendly.details, contains('wiki/EJS'));
    });
  });

  testWidgets('SyncoApp renders modern UI with mode switcher and queue', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final provider = AppStateProvider(prefs);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppStateProvider>.value(
        value: provider,
        child: const SyncoApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Synco'), findsOneWidget);
    expect(find.text('Videos'), findsOneWidget);
    expect(find.text('Music / MP3'), findsOneWidget);
    expect(find.text('DOWNLOAD QUEUE'), findsOneWidget);

    // Switch to Music / MP3 mode
    await tester.tap(find.text('Music / MP3'));
    await tester.pumpAndSettle();
    expect(provider.mediaMode, AppMediaMode.music);
  });
}
