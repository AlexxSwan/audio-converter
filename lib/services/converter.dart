import 'dart:async';
import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/statistics.dart';
import 'package:path/path.dart' as p;
import '../models/task.dart';

class ConverterService {
  /// Получить длительность аудио в секундах через ffprobe.
  /// Возвращает null, если не удалось.
  static Future<double?> getDuration(String filePath) async {
    try {
      // ffmpeg_kit_flutter_new предоставляет FFprobeKit
      final session = await FFmpegKit.execute(
        '-i "$filePath" -hide_banner -nostats',
      );
      // Не самый эффективный способ, но работающий
      final logs = await session.getAllLogs();
      final output = logs.map((l) => l.getMessage()).join('\n');
      final match = RegExp(r'Duration:\s*(\d+):(\d+):(\d+(?:\.\d+)?)').firstMatch(output);
      if (match == null) return null;
      final h = int.parse(match.group(1)!);
      final m = int.parse(match.group(2)!);
      final s = double.parse(match.group(3)!);
      return h * 3600 + m * 60 + s;
    } catch (e) {
      return null;
    }
  }

  /// Построить список аргументов ffmpeg для конвертации.
  static String buildArgs(ConvertTask task) {
    final buf = StringBuffer();
    buf.write('-y -i "${task.inputPath}" ');

    // Перенос метаданных
    if (task.preserveMetadata) {
      buf.write('-map_metadata 0 ');
    }

    // Нормализация громкости (EBU R128)
    if (task.normalize) {
      buf.write('-af loudnorm=I=-16:TP=-1.5:LRA=11 ');
    }

    // Кодек по формату
    switch (task.format) {
      case AudioFormat.mp3:
        buf.write('-c:a libmp3lame ');
        if (task.bitrate == 'V0') {
          buf.write('-q:a 0 ');
        } else {
          buf.write('-b:a ${task.bitrate}k ');
        }
        if (task.preserveMetadata) {
          buf.write('-id3v2_version 3 -write_id3v1 1 ');
        }
        break;
      case AudioFormat.wav:
        buf.write('-c:a pcm_s16le ');
        break;
      case AudioFormat.flac:
        buf.write('-c:a flac -compression_level 8 ');
        break;
      case AudioFormat.m4a:
        buf.write('-c:a aac -b:a ${task.bitrate}k ');
        break;
    }

    buf.write('"${task.outputPath}"');
    return buf.toString();
  }

  /// Конвертировать один файл.
  /// onProgress(percent) — колбэк прогресса (0-100).
  /// cancelToken — токен для отмены.
  static Future<ConvertTask> convertOne(
    ConvertTask task, {
    required void Function(int percent) onProgress,
    required CancelToken cancelToken,
  }) async {
    // Быстрая проверка отмены
    if (cancelToken.isCancelled) {
      task.status = TaskStatus.cancelled;
      return task;
    }

    // Получаем длительность для расчёта прогресса
    final duration = await getDuration(task.inputPath);

    // Строим аргументы
    final args = buildArgs(task);

    // Создаём контроллер для отслеживания прогресса
    final completer = Completer<ConvertTask>();
    int lastPercent = 0;

    // Подписываемся на статистику ffmpeg
    FFmpegKitConfig.enableStatisticsCallback((statistics) {
      if (duration != null && duration > 0 && !completer.isCompleted) {
        // statistics.getTime() — текущая позиция в миллисекундах
        final currentTime = statistics.getTime() / 1000.0;
        final percent = (currentTime / duration * 100).clamp(1, 99).toInt();
        if (percent > lastPercent) {
          lastPercent = percent;
          onProgress(percent);
        }
      }
    });

    // Запускаем ffmpeg
    FFmpegKit.executeAsync(args, (session) async {
      // Отписываемся от статистики
      FFmpegKitConfig.enableStatisticsCallback(null);

      if (completer.isCompleted) return;

      final returnCode = await session.getReturnCode();
      final output = task.outputPath;

      // Проверяем отмену
      if (cancelToken.isCancelled) {
        // Удаляем недоконвертированный файл
        try {
          final f = File(output);
          if (await f.exists()) await f.delete();
        } catch (_) {}
        task.status = TaskStatus.cancelled;
        task.progress = 0;
        completer.complete(task);
        return;
      }

      if (ReturnCode.isSuccess(returnCode)) {
        // Успех
        try {
          final f = File(output);
          if (await f.exists()) {
            task.outputSize = await f.length();
          }
        } catch (_) {}
        task.status = TaskStatus.done;
        task.progress = 100;
      } else {
        // Ошибка
        final logs = await session.getAllLogs();
        final errorText = logs.map((l) => l.getMessage()).join('\n');
        final tail = errorText.split('\n').skip(errorText.split('\n').length - 5).join('\n');
        task.status = TaskStatus.error;
        task.errorMessage = tail.isNotEmpty ? tail : 'Неизвестная ошибка ffmpeg';
      }
      completer.complete(task);
    });

    return completer.future;
  }
}

/// Токен для отмены конвертации
class CancelToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
  void reset() => _cancelled = false;
}
