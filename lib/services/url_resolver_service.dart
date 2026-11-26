import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:synco/models/download_models.dart';

/// Parses messy mobile share text, extracts clean URLs, detects platform and
/// content types (single, playlist, channel, DRM music services), resolves
/// Spotify / Apple Music / Amazon Music metadata into searchable audio queries,
/// and translates raw engine errors into concise, actionable messages.
class UrlResolverService {
  static final RegExp _urlRegex = RegExp(
    r'https?://[^\s<>"{}|\\^`\[\]]+',
    caseSensitive: false,
  );

  /// Extracts a clean URL and optional track/artist hint from any pasted or
  /// shared text (e.g. Amazon Music, Spotify, Apple Music, YouTube share text).
  static ParsedMediaInput parseInput(
    String rawText, {
    AppMediaMode preferredMode = AppMediaMode.video,
  }) {
    final trimmed = rawText.trim();
    if (trimmed.isEmpty) {
      return const ParsedMediaInput(
        rawInput: '',
        cleanUrl: '',
        platform: MediaSourcePlatform.generic,
        contentType: MediaContentType.video,
        displayDomain: '',
        isValid: false,
      );
    }

    final match = _urlRegex.firstMatch(trimmed);
    if (match == null) {
      // Allow direct song/video search queries when the user types text
      // without a URL (especially useful in Music / MP3 mode).
      final looksLikeDomain = RegExp(
        r'^(www\.)?[a-zA-Z0-9-]+\.[a-zA-Z]{2,}(/.*)?$',
      ).hasMatch(trimmed);
      if (looksLikeDomain) {
        return parseInput('https://$trimmed', preferredMode: preferredMode);
      }

      if (trimmed.length >= 2) {
        return ParsedMediaInput(
          rawInput: trimmed,
          cleanUrl: trimmed,
          platform: preferredMode == AppMediaMode.music
              ? MediaSourcePlatform.youtubeMusic
              : MediaSourcePlatform.youtube,
          contentType: MediaContentType.search,
          searchHint: _cleanSearchTerms(trimmed),
          displayDomain: 'Search Query',
          isValid: true,
        );
      }

      return ParsedMediaInput(
        rawInput: trimmed,
        cleanUrl: '',
        platform: MediaSourcePlatform.generic,
        contentType: MediaContentType.video,
        displayDomain: '',
        isValid: false,
      );
    }

    String cleanUrl = match.group(0) ?? '';
    // Strip trailing sentence punctuation that share sheets sometimes append
    cleanUrl = cleanUrl.replaceAll(RegExp(r'[.,;:!?)>\]]+$'), '');

    final Uri? uri = Uri.tryParse(cleanUrl);
    if (uri == null || uri.host.isEmpty) {
      return ParsedMediaInput(
        rawInput: trimmed,
        cleanUrl: '',
        platform: MediaSourcePlatform.generic,
        contentType: MediaContentType.video,
        displayDomain: '',
        isValid: false,
      );
    }

    final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
    final platform = _detectPlatform(host);
    final contentType = _detectContentType(uri, platform, preferredMode);
    final shareTextHint = _extractShareTextHint(trimmed, cleanUrl);

    return ParsedMediaInput(
      rawInput: trimmed,
      cleanUrl: cleanUrl,
      platform: platform,
      contentType: contentType,
      searchHint: shareTextHint,
      displayDomain: host,
      isValid: true,
    );
  }

  /// Checks whether clipboard text contains a recognizable media link.
  static ParsedMediaInput? extractClipboardMediaLink(
    String? clipboardText, {
    AppMediaMode preferredMode = AppMediaMode.video,
  }) {
    if (clipboardText == null || clipboardText.trim().isEmpty) return null;
    if (!_urlRegex.hasMatch(clipboardText)) return null;
    final parsed = parseInput(clipboardText, preferredMode: preferredMode);
    if (!parsed.isValid || parsed.cleanUrl.isEmpty) return null;
    return parsed;
  }

  static MediaSourcePlatform _detectPlatform(String host) {
    if (host == 'music.youtube.com') return MediaSourcePlatform.youtubeMusic;
    if (host.contains('youtube.com') ||
        host == 'youtu.be' ||
        host.contains('youtube-nocookie.com')) {
      return MediaSourcePlatform.youtube;
    }
    if (host.contains('spotify.com') || host == 'spoti.fi') {
      return MediaSourcePlatform.spotify;
    }
    if (host.contains('music.apple.com') || host.contains('itunes.apple.com')) {
      return MediaSourcePlatform.appleMusic;
    }
    if (host.contains('music.amazon.') || host.contains('amazon.')) {
      return MediaSourcePlatform.amazonMusic;
    }
    if (host.contains('soundcloud.com') || host.contains('snd.sc')) {
      return MediaSourcePlatform.soundcloud;
    }
    if (host.contains('instagram.com') || host.contains('instagr.am')) {
      return MediaSourcePlatform.instagram;
    }
    if (host.contains('tiktok.com')) return MediaSourcePlatform.tiktok;
    if (host == 'x.com' ||
        host.contains('twitter.com') ||
        host == 't.co') {
      return MediaSourcePlatform.twitter;
    }
    if (host.contains('reddit.com') || host == 'redd.it') {
      return MediaSourcePlatform.reddit;
    }
    if (host.contains('vimeo.com')) return MediaSourcePlatform.vimeo;
    if (host.contains('twitch.tv')) return MediaSourcePlatform.twitch;
    if (host.contains('facebook.com') || host == 'fb.watch') {
      return MediaSourcePlatform.facebook;
    }
    return MediaSourcePlatform.generic;
  }

  static MediaContentType _detectContentType(
    Uri uri,
    MediaSourcePlatform platform,
    AppMediaMode preferredMode,
  ) {
    final path = uri.path.toLowerCase();
    final query = uri.queryParameters;

    if (platform.isYouTubeFamily) {
      // Explicit channel URLs: /@handle, /channel/UC..., /c/name, /user/name
      if (path.startsWith('/@') ||
          path.startsWith('/channel/') ||
          path.startsWith('/c/') ||
          path.startsWith('/user/')) {
        return MediaContentType.channel;
      }

      // Explicit playlist URLs or watch URLs with a playlist parameter
      if (path.contains('/playlist') ||
          (query.containsKey('list') &&
              (query['list']?.isNotEmpty ?? false))) {
        return MediaContentType.playlist;
      }

      if (platform == MediaSourcePlatform.youtubeMusic ||
          preferredMode == AppMediaMode.music) {
        return MediaContentType.audio;
      }
      return MediaContentType.video;
    }

    if (platform == MediaSourcePlatform.spotify) {
      if (path.contains('/playlist/') || path.contains('/album/')) {
        return MediaContentType.playlist;
      }
      if (path.contains('/artist/')) return MediaContentType.channel;
      return MediaContentType.audio;
    }

    if (platform == MediaSourcePlatform.appleMusic) {
      // Apple Music song links look like /album/name/123?i=456
      if (query.containsKey('i')) return MediaContentType.audio;
      if (path.contains('/playlist/') || path.contains('/album/')) {
        return MediaContentType.playlist;
      }
      if (path.contains('/artist/')) return MediaContentType.channel;
      return MediaContentType.audio;
    }

    if (platform == MediaSourcePlatform.amazonMusic) {
      if (query.containsKey('trackAsin') || path.contains('/tracks/')) {
        return MediaContentType.audio;
      }
      if (path.contains('/playlists/') || path.contains('/albums/')) {
        return MediaContentType.playlist;
      }
      return MediaContentType.audio;
    }

    if (platform == MediaSourcePlatform.soundcloud) {
      if (path.contains('/sets/')) return MediaContentType.playlist;
      return MediaContentType.audio;
    }

    if (path.contains('/playlist') || query.containsKey('list')) {
      return MediaContentType.playlist;
    }

    return preferredMode == AppMediaMode.music
        ? MediaContentType.audio
        : MediaContentType.video;
  }

  /// Extracts a clean `Track Artist` search hint from share sheet blurbs
  /// such as:
  ///   `"Check out T.I.A. [Explicit] by K'naan on Amazon Music\nhttps://..."`
  static String? _extractShareTextHint(String fullText, String extractedUrl) {
    final beforeOrAfter = fullText.replaceFirst(extractedUrl, '').trim();
    if (beforeOrAfter.isEmpty) return null;

    // Pattern 1: "Check out <Title> by <Artist> on Amazon Music"
    final amazonMatch = RegExp(
      r'check out\s+(.+?)\s+by\s+(.+?)(?:\s+on\s+amazon music|\s+on\s+spotify|\s+on\s+apple music|$)',
      caseSensitive: false,
    ).firstMatch(beforeOrAfter);
    if (amazonMatch != null) {
      final title = _cleanSearchTerms(amazonMatch.group(1) ?? '');
      final artist = _cleanSearchTerms(amazonMatch.group(2) ?? '');
      if (title.isNotEmpty) {
        return artist.isNotEmpty ? '$title $artist' : title;
      }
    }

    // Pattern 2: "Listen to <Title> by <Artist>"
    final listenMatch = RegExp(
      r'(?:listen to|check out)\s+(.+?)(?:\s+on\s+\w+.*)?$',
      caseSensitive: false,
    ).firstMatch(beforeOrAfter);
    if (listenMatch != null) {
      final cleaned = _cleanSearchTerms(listenMatch.group(1) ?? '');
      if (cleaned.length >= 3) return cleaned;
    }

    // Pattern 3: Short descriptive line accompanying the URL
    final firstLine = beforeOrAfter
        .split('\n')
        .map((e) => e.trim())
        .firstWhere((e) => e.isNotEmpty, orElse: () => '');
    final cleaned = _cleanSearchTerms(firstLine);
    if (cleaned.length >= 3 && cleaned.length <= 120) {
      return cleaned;
    }
    return null;
  }

  static String _cleanSearchTerms(String text) {
    return text
        .replaceAll(RegExp(r'\[(?:explicit|clean|official.*?)\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\((?:explicit|clean)\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'["“”]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Resolves Spotify, Apple Music, Amazon Music, or raw search text into a
  /// structured [ResolvedMusicTrack] that can be fetched via YouTube/yt-dlp.
  static Future<ResolvedMusicTrack?> resolveMusicTrack(
    ParsedMediaInput parsed,
  ) async {
    if (parsed.contentType == MediaContentType.search) {
      final query = parsed.searchHint ?? parsed.cleanUrl;
      return ResolvedMusicTrack(
        title: query,
        artist: 'YouTube Search',
        thumbnail: '',
        searchQuery: query,
        sourceLabel: 'Search',
      );
    }

    // 1. Spotify via public oEmbed API (fast, no API key needed)
    if (parsed.platform == MediaSourcePlatform.spotify) {
      try {
        final oembedUri = Uri.parse(
          'https://open.spotify.com/oembed?url=${Uri.encodeComponent(parsed.cleanUrl)}',
        );
        final resp = await http.get(oembedUri).timeout(const Duration(seconds: 8));
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          final title = _cleanSearchTerms(data['title']?.toString() ?? '');
          final thumb = data['thumbnail_url']?.toString() ?? '';
          if (title.isNotEmpty) {
            final query = parsed.searchHint != null &&
                    parsed.searchHint!.length > title.length
                ? parsed.searchHint!
                : title;
            return ResolvedMusicTrack(
              title: title,
              artist: 'Spotify',
              thumbnail: thumb,
              searchQuery: '$query official audio',
              sourceLabel: 'Spotify → YouTube',
            );
          }
        }
      } catch (_) {
        // Fall through to HTML/share-hint fallback
      }
    }

    // 2. Apple Music via iTunes Lookup API
    if (parsed.platform == MediaSourcePlatform.appleMusic) {
      try {
        final uri = Uri.parse(parsed.cleanUrl);
        final trackId = uri.queryParameters['i'] ??
            RegExp(r'/(\d{6,})').firstMatch(uri.path)?.group(1);
        if (trackId != null) {
          final lookupUri = Uri.parse(
            'https://itunes.apple.com/lookup?id=$trackId',
          );
          final resp = await http
              .get(lookupUri)
              .timeout(const Duration(seconds: 8));
          if (resp.statusCode == 200) {
            final data = jsonDecode(resp.body) as Map<String, dynamic>;
            final results = data['results'] as List?;
            if (results != null && results.isNotEmpty && results.first is Map) {
              final item = results.first as Map;
              final trackName = _cleanSearchTerms(
                item['trackName']?.toString() ??
                    item['collectionName']?.toString() ??
                    '',
              );
              final artistName = _cleanSearchTerms(
                item['artistName']?.toString() ?? '',
              );
              final artwork = (item['artworkUrl100']?.toString() ?? '')
                  .replaceAll('100x100', '600x600');
              if (trackName.isNotEmpty) {
                return ResolvedMusicTrack(
                  title: trackName,
                  artist: artistName.isNotEmpty ? artistName : 'Apple Music',
                  thumbnail: artwork,
                  searchQuery: '$trackName $artistName official audio'.trim(),
                  sourceLabel: 'Apple Music → YouTube',
                );
              }
            }
          }
        }
      } catch (_) {
        // Fall through to share-hint / OG scrape fallback
      }
    }

    // 3. Share-text hint (handles Amazon Music immediately even when scraped pages block bots!)
    if (parsed.searchHint != null && parsed.searchHint!.isNotEmpty) {
      return ResolvedMusicTrack(
        title: parsed.searchHint!,
        artist: parsed.platform.displayName,
        thumbnail: '',
        searchQuery: '${parsed.searchHint!} official audio',
        sourceLabel: '${parsed.platform.displayName} → YouTube',
      );
    }

    // 4. Generic OpenGraph <meta property="og:title"> fallback for DRM music pages
    if (parsed.platform.isDrmMusicService) {
      try {
        final resp = await http
            .get(
              Uri.parse(parsed.cleanUrl),
              headers: const {
                'User-Agent':
                    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
              },
            )
            .timeout(const Duration(seconds: 8));
        if (resp.statusCode == 200) {
          final body = resp.body;
          final ogTitle = _extractMetaContent(body, 'og:title') ??
              _extractHtmlTitle(body);
          final ogImage = _extractMetaContent(body, 'og:image') ?? '';
          if (ogTitle != null && ogTitle.trim().isNotEmpty) {
            final cleanedTitle = _cleanSearchTerms(
              ogTitle
                  .replaceAll(RegExp(r'\s*[-|]\s*(Amazon Music|Spotify|Apple Music).*$', caseSensitive: false), '')
                  .trim(),
            );
            if (cleanedTitle.isNotEmpty) {
              return ResolvedMusicTrack(
                title: cleanedTitle,
                artist: parsed.platform.displayName,
                thumbnail: ogImage,
                searchQuery: '$cleanedTitle official audio',
                sourceLabel: '${parsed.platform.displayName} → YouTube',
              );
            }
          }
        }
      } catch (_) {
        // Ignore scrape failure
      }
    }

    return null;
  }

  static String? _extractMetaContent(String html, String property) {
    final pattern = RegExp(
      '<meta[^>]+(?:property|name)=["\']$property["\'][^>]+content=["\']([^"\']+)["\']',
      caseSensitive: false,
    );
    final match = pattern.firstMatch(html);
    if (match != null) return match.group(1);

    final reversePattern = RegExp(
      '<meta[^>]+content=["\']([^"\']+)["\'][^>]+(?:property|name)=["\']$property["\']',
      caseSensitive: false,
    );
    return reversePattern.firstMatch(html)?.group(1);
  }

  static String? _extractHtmlTitle(String html) {
    final match = RegExp(
      r'<title[^>]*>([^<]+)</title>',
      caseSensitive: false,
    ).firstMatch(html);
    return match?.group(1);
  }

  /// Translates raw yt-dlp, YouTube Explode, or network error logs into a
  /// concise, non-overflowing summary plus an actionable fix guide.
  static FriendlyErrorInfo formatFriendlyError(String rawError) {
    final cleanRaw = rawError.replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
    final lower = cleanRaw.toLowerCase();

    if (lower.contains('wiki/ejs') ||
        lower.contains('n challenge solving failed') ||
        lower.contains('signature solving failed') ||
        lower.contains('javascript runtime')) {
      return FriendlyErrorInfo(
        summary:
            'YouTube JS challenge failed — Deno or Node.js runtime required.',
        details: cleanRaw,
        fixHint:
            'Install Deno (recommended) or Node.js, update yt-dlp in Settings → Engine, or enable browser cookies.',
        isEngineFixable: true,
      );
    }

    if (lower.contains('sabr') ||
        lower.contains('only images are available') ||
        lower.contains('requested format is not available')) {
      return FriendlyErrorInfo(
        summary:
            'YouTube restricted streams for this format (SABR / format mismatch).',
        details: cleanRaw,
        fixHint:
            'Tap Retry to use fallback clients, try "Best" quality, update yt-dlp, or enable browser cookies in Settings.',
        isEngineFixable: true,
      );
    }

    if (lower.contains('is not a valid url') ||
        lower.contains('invalid url') ||
        lower.contains('could not extract a valid')) {
      return FriendlyErrorInfo(
        summary: 'Invalid or unsupported link format.',
        details: cleanRaw,
        fixHint:
            'Paste a direct YouTube, Spotify, Apple Music, Amazon Music, or media URL.',
      );
    }

    if (lower.contains('sign in to confirm') ||
        lower.contains('not a bot') ||
        lower.contains('age-restricted') ||
        lower.contains('confirm your age')) {
      return FriendlyErrorInfo(
        summary: 'YouTube requires account verification for this video.',
        details: cleanRaw,
        fixHint:
            'Go to Settings → Engine and select a browser for cookies (Chrome, Firefox, Safari, or Edge).',
        isEngineFixable: true,
      );
    }

    if (lower.contains('video unavailable') ||
        lower.contains('private video') ||
        lower.contains('members-only') ||
        lower.contains('has been removed')) {
      return FriendlyErrorInfo(
        summary: 'This video is private, region-locked, or unavailable.',
        details: cleanRaw,
        fixHint:
            'Check that the link opens publicly in a browser, or configure cookies in Settings if you have access.',
      );
    }

    if (lower.contains('no such file or directory') &&
        lower.contains('yt-dlp')) {
      return FriendlyErrorInfo(
        summary: 'yt-dlp binary not found on this computer.',
        details: cleanRaw,
        fixHint:
            'Install yt-dlp, ffmpeg, and deno (e.g. "brew install yt-dlp ffmpeg deno" on macOS or "winget install yt-dlp FFmpeg DenoLand.Deno" on Windows).',
        isEngineFixable: true,
      );
    }

    if (lower.contains('backend') ||
        lower.contains('connection refused') ||
        lower.contains('failed host lookup') ||
        lower.contains('socketexception')) {
      return FriendlyErrorInfo(
        summary: 'Network or backend server connection failed.',
        details: cleanRaw,
        fixHint:
            'Check your internet connection. For Web or non-YouTube mobile links, configure a reachable Synco backend URL in Settings.',
        isEngineFixable: true,
      );
    }

    if (lower.contains('cancelled')) {
      return FriendlyErrorInfo(
        summary: 'Download cancelled.',
        details: cleanRaw,
        fixHint: 'Tap Retry to start this download again.',
      );
    }

    // Generic concise extraction: grab the first ERROR: line if present
    final errorLineMatch = RegExp(
      r'ERROR:\s*(.+)',
      caseSensitive: false,
    ).firstMatch(cleanRaw);
    final extracted = errorLineMatch?.group(1)?.trim() ??
        cleanRaw.split('\n').firstWhere(
              (line) => line.trim().isNotEmpty,
              orElse: () => 'Download failed unexpectedly.',
            );

    final concise = extracted.length > 120
        ? '${extracted.substring(0, 117)}...'
        : extracted;

    return FriendlyErrorInfo(
      summary: concise,
      details: cleanRaw,
      fixHint: 'Tap Retry or inspect technical logs for details.',
    );
  }
}
