/// Format sorter builder mirroring Seal's DownloadPreferences.toFormatSorter()
class FormatSorter {
  static const String h264Compatibility = 'proto,vcodec:h264,ext';
  static const String av1Quality = 'vcodec:av01,vcodec:vp9.2';
  static const String aacAudio = 'acodec:aac,abr~192';
  static const String opusAudio = 'acodec:opus,abr~160';

  /// Build a combined -S sorter string
  static String buildSorter({
    String? resolution,
    bool preferCompatibility = true,
    bool isAudioOnly = false,
    String? audioFormat, // 'mp3', 'm4a', 'opus', 'flac'
  }) {
    final List<String> segments = [];

    if (isAudioOnly) {
      if (audioFormat == 'm4a') {
        segments.add('acodec:aac');
        segments.add('abr~256');
      } else if (audioFormat == 'opus') {
        segments.add('acodec:opus');
        segments.add('abr~160');
      } else {
        segments.add('abr~320');
        segments.add('acodec:opus');
        segments.add('acodec:aac');
      }
      return segments.join(',');
    }

    // Video sorting
    if (resolution != null && resolution.isNotEmpty && resolution != 'Best') {
      final cleanRes = resolution.replaceAll('p', '').trim();
      segments.add('res:$cleanRes');
    }

    if (preferCompatibility) {
      segments.add('proto');
      segments.add('vcodec:h264');
      segments.add('acodec:aac');
      segments.add('ext');
    } else {
      segments.add('vcodec:av01');
      segments.add('vcodec:vp9.2');
      segments.add('acodec:opus');
    }

    return segments.join(',');
  }
}
