/// Модели данных для аудио-конвертера

/// Поддерживаемые форматы конвертации
enum AudioFormat {
  mp3('MP3', '🎧', '320 kbps', 'mp3'),
  wav('WAV', '🔊', 'lossless', 'wav'),
  flac('FLAC', '💾', 'без потерь', 'flac'),
  m4a('M4A/AAC', '📱', '256 kbps', 'm4a');

  final String displayName;
  final String icon;
  final String description;
  final String extension;
  const AudioFormat(this.displayName, this.icon, this.description, this.extension);
}

/// Пресеты качества
enum Preset {
  music('🎵 Музыка', '320 kbps MP3'),
  voice('🎙️ Голос', '192 kbps MP3 + нормализация'),
  podcast('📻 Подкаст', '128 kbps MP3 + нормализация'),
  archive('💾 Архив', 'FLAC без потерь');

  final String label;
  final String description;
  const Preset(this.label, this.description);
}

/// Статус задачи конвертации
enum TaskStatus {
  queued('В очереди'),
  converting('Конвертация…'),
  done('Готово'),
  error('Ошибка'),
  cancelled('Отменено');

  final String label;
  const TaskStatus(this.label);
}

/// Одна задача конвертации
class ConvertTask {
  final String inputPath;
  final String inputName;
  final int inputSize;
  final String outputPath;
  final AudioFormat format;
  final String bitrate;
  final bool normalize;
  final bool preserveMetadata;

  TaskStatus status;
  int progress; // 0-100
  String? errorMessage;
  int? outputSize;

  ConvertTask({
    required this.inputPath,
    required this.inputName,
    required this.inputSize,
    required this.outputPath,
    required this.format,
    required this.bitrate,
    required this.normalize,
    required this.preserveMetadata,
    this.status = TaskStatus.queued,
    this.progress = 0,
    this.errorMessage,
    this.outputSize,
  });

  String get formattedInputSize {
    return _formatBytes(inputSize);
  }

  String? get formattedOutputSize {
    if (outputSize == null) return null;
    return _formatBytes(outputSize!);
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes Б';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} КБ';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / 1024 / 1024).toStringAsFixed(1)} МБ';
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)} ГБ';
  }
}
