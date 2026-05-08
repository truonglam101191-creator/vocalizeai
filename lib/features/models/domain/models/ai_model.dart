class AiModel {
  final String name;
  final String type; // 'whisper' or 'tts'
  final bool downloaded;
  final String? language;
  final String? quality;

  AiModel({
    required this.name,
    required this.type,
    required this.downloaded,
    this.language,
    this.quality,
  });

  factory AiModel.fromJson(Map<String, dynamic> json) {
    return AiModel(
      name: json['name'] as String,
      type: json['type'] as String,
      downloaded: json['downloaded'] as bool,
      language: json['language'] as String?,
      quality: json['quality'] as String?,
    );
  }
}
