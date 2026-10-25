import 'package:flutter/material.dart';

enum PresetType {
  bestForPhone,
  highestAudio,
  dataSaver,
  ultra4k,
  custom,
}

class QualityPreset {
  final PresetType type;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isAudioOnly;
  final String? preferredResolution; // e.g. "1080", "720", "480", "2160"
  final String? preferredVideoCodec; // e.g. "h264", "av01", "vp9"
  final String? preferredAudioCodec; // e.g. "aac", "opus", "mp3", "flac"
  final String formatSorter;

  const QualityPreset({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.isAudioOnly = false,
    this.preferredResolution,
    this.preferredVideoCodec,
    this.preferredAudioCodec,
    required this.formatSorter,
  });

  static const QualityPreset bestForPhone = QualityPreset(
    type: PresetType.bestForPhone,
    title: 'Best for Mobile',
    subtitle: '1080p H.264 + AAC • Smooth playback & battery friendly',
    icon: Icons.phone_iphone_rounded,
    isAudioOnly: false,
    preferredResolution: '1080',
    preferredVideoCodec: 'h264',
    preferredAudioCodec: 'aac',
    formatSorter: 'res:1080,vcodec:h264,acodec:aac,proto',
  );

  static const QualityPreset highestAudio = QualityPreset(
    type: PresetType.highestAudio,
    title: 'Audiophile Hi-Fi',
    subtitle: 'Studio audio • Tagged metadata & square album artwork',
    icon: Icons.headphones_rounded,
    isAudioOnly: true,
    preferredAudioCodec: 'mp3',
    formatSorter: 'acodec:opus,abr~320,acodec:aac',
  );

  static const QualityPreset dataSaver = QualityPreset(
    type: PresetType.dataSaver,
    title: 'Data Saver',
    subtitle: '480p efficient • Fast downloads on metered connections',
    icon: Icons.energy_savings_leaf_rounded,
    isAudioOnly: false,
    preferredResolution: '480',
    preferredVideoCodec: 'h264',
    preferredAudioCodec: 'aac',
    formatSorter: 'res:480,res:360,vcodec:h264,proto',
  );

  static const QualityPreset ultra4k = QualityPreset(
    type: PresetType.ultra4k,
    title: 'Cinema Ultra 4K',
    subtitle: '2160p+ AV1/VP9 • Maximum bitrate & fidelity',
    icon: Icons.movie_filter_rounded,
    isAudioOnly: false,
    preferredResolution: '2160',
    preferredVideoCodec: 'av01',
    preferredAudioCodec: 'opus',
    formatSorter: 'res:2160,res:1440,vcodec:av01,vcodec:vp9.2',
  );

  static const List<QualityPreset> all = [
    bestForPhone,
    highestAudio,
    dataSaver,
    ultra4k,
  ];

  static QualityPreset fromType(PresetType type) {
    switch (type) {
      case PresetType.bestForPhone:
        return bestForPhone;
      case PresetType.highestAudio:
        return highestAudio;
      case PresetType.dataSaver:
        return dataSaver;
      case PresetType.ultra4k:
        return ultra4k;
      case PresetType.custom:
        return bestForPhone;
    }
  }
}
