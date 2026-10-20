import 'dart:async';
import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/statistics.dart';
import 'package:ffmpeg_kit_flutter_new/media_information.dart';
import 'package:ffmpeg_kit_flutter_new/media_information_session.dart';
import '../models/task.dart';

class ConverterService {
  /// Получить длительность аудио в секундах через FFprobeKit.
  /// Возвращает null, если не удалось.
  static Future<double?> getDuration(String filePath) async {
    try {
      final session = await FFprobeKit.getMediaInformation(filePath);
      final info = await session.getMediaInformation();
      if (info == null) return null;
      final dur = info.getDuration();
      if (dur == null) return null;
      final d = double.tryParse(dur);
      return d != null && d > 0 ? d : null;
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

    // Запускаем ffmpeg с колбэком статистики прямо в executeAsync.
    // executeAsync возвращает Future<FFmpegSession>, из которого можно
    // получить sessionId для отмены.
    final completer = Completer<ConvertTask>();
    int lastPercent = 0;
    FFmpegSession? session;

    FFmpegKit.executeAsync(
      args,
      // Завершение сессии
      (FFmpegSession completedSession) async {
        if (completer.isCompleted) return;

        final returnCode = await completedSession.getReturnCode();

        // Проверяем отмену
        if (cancelToken.isCancelled) {
          // Удаляем недоконвертированный файл
          try {
            final f = File(task.outputPath);
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
            final f = File(task.outputPath);
            if (await f.exists()) {
              task.outputSize = await f.length();
            }
          } catch (_) {}
          task.status = TaskStatus.done;
          task.progress = 100;
        } else {
          // Ошибка
          final logs = await completedSession.getLogs();
          final errorText = logs.map((l) => l.getMessage()).join('\n');
          final lines = errorText.split('\n');
          final tail = lines.length > 5
              ? lines.skip(lines.length - 5).join('\n')
              : errorText;
          task.status = TaskStatus.error;
          task.errorMessage = tail.isNotEmpty ? tail : 'Неизвестная ошибка ffmpeg';
        }
        completer.complete(task);
      },
      // Логи (не используем)
      null,
      // Статистика — для прогресса
      (Statistics? stats) {
        if (stats == null || duration == null || duration <= 0) return;
        if (completer.isCompleted) return;
        final currentTime = stats.getTime() / 1000.0;
        final percent = (currentTime / duration * 100).clamp(1, 99).toInt();
        if (percent > lastPercent) {
          lastPercent = percent;
          onProgress(percent);
        }
      },
    ).then((FFmpegSession s) {
      session = s;
    });

    // Ждём завершения конвертации, параллельно проверяя отмену каждые 200мс
    while (!completer.isCompleted) {
      if (cancelToken.isCancelled && session != null) {
        final sid = await session!.getSessionId();
        await FFmpegKit.cancel(sid);
      }
      await Future.delayed(const Duration(milliseconds: 200));
    }

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
