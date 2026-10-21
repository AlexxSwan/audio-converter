import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../main.dart';
import '../models/task.dart';
import '../services/converter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<ConvertTask> _tasks = [];
  AudioFormat _selectedFormat = AudioFormat.mp3;
  String _selectedBitrate = '320';
  bool _normalize = false;
  bool _preserveMetadata = true;
  bool _showAdvanced = false;
  bool _isConverting = false;
  final CancelToken _cancelToken = CancelToken();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🎵 Audio Converter'),
        centerTitle: false,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) => _applyPreset(value),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'music', child: Text('🎵 Музыка (320 MP3)')),
              const PopupMenuItem(value: 'voice', child: Text('🎙️ Голос (192 + нормализация)')),
              const PopupMenuItem(value: 'podcast', child: Text('📻 Подкаст (128 + нормализация)')),
              const PopupMenuItem(value: 'archive', child: Text('💾 Архив (FLAC)')),
            ],
            icon: const Icon(Icons.tune),
            tooltip: 'Пресеты',
          ),
          // Кнопка выбора темы
          PopupMenuButton<String>(
            onSelected: (value) {
              ThemeMode mode;
              switch (value) {
                case 'light':
                  mode = ThemeMode.light;
                  break;
                case 'dark':
                  mode = ThemeMode.dark;
                  break;
                default:
                  mode = ThemeMode.system;
              }
              AudioConverterApp.of(context)?.setThemeMode(mode);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'system', child: Text('🌗 Системная')),
              const PopupMenuItem(value: 'light', child: Text('☀️ Светлая')),
              const PopupMenuItem(value: 'dark', child: Text('🌙 Тёмная')),
            ],
            icon: const Icon(Icons.palette),
            tooltip: 'Тема оформления',
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showAbout,
            tooltip: 'О программе',
          ),
        ],
      ),
      body: _tasks.isEmpty ? _buildEmptyState() : _buildQueueView(),
      floatingActionButton: _tasks.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _isConverting ? null : _startConversion,
              backgroundColor: _isConverting ? Colors.grey : Colors.orange,
              foregroundColor: Colors.white,
              icon: _isConverting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(_isConverting ? 'Конвертация…' : 'Конвертировать'),
            ),
    );
  }

  // ─── Пустое состояние — выбор файлов ─────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.audio_file, size: 96, color: Colors.orange),
            const SizedBox(height: 24),
            const Text(
              'Audio Converter',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Конвертер аудио в MP3, WAV, M4A, FLAC',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 48),
            // Выбор формата
            const Text('Выберите формат:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: AudioFormat.values.map((f) {
                final selected = f == _selectedFormat;
                final cs = Theme.of(context).colorScheme;
                return ChoiceChip(
                  label: Text('${f.icon} ${f.displayName}'),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedFormat = f),
                  selectedColor: Colors.orange,
                  backgroundColor: cs.surfaceContainerHighest,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : cs.onSurface,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            // Кнопки выбора файлов
            FilledButton.icon(
              onPressed: _pickFiles,
              icon: const Icon(Icons.file_open),
              label: const Text('Выбрать файлы'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.orange,
                minimumSize: const Size.fromHeight(56),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickFolder,
              icon: const Icon(Icons.folder_open),
              label: const Text('Выбрать папку'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                foregroundColor: Colors.orange,
                side: const BorderSide(color: Colors.orange),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Очередь конвертации ─────────────────────────────────────────────────

  Widget _buildQueueView() {
    return Column(
      children: [
        // Тонкая панель формата сверху
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Row(
            children: [
              Text('Формат: ', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              DropdownButton<AudioFormat>(
                value: _selectedFormat,
                underline: const SizedBox(),
                items: AudioFormat.values
                    .map((f) => DropdownMenuItem(
                          value: f,
                          child: Text('${f.icon} ${f.displayName}'),
                        ))
                    .toList(),
                onChanged: (f) {
                  if (f != null) setState(() => _selectedFormat = f);
                },
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _isConverting ? null : () => setState(() => _showAdvanced = !_showAdvanced),
                icon: Icon(_showAdvanced ? Icons.expand_less : Icons.expand_more),
                label: const Text('Настройки'),
              ),
              IconButton(
                onPressed: _isConverting ? null : _clearAll,
                icon: const Icon(Icons.delete_sweep),
                tooltip: 'Очистить',
              ),
            ],
          ),
        ),
        // Расширенные настройки (свернутые по умолчанию)
        if (_showAdvanced) _buildAdvancedSettings(),
        // Кнопка отмены при конвертации
        if (_isConverting)
          Container(
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Text('Конвертация…')),
                TextButton(
                  onPressed: _cancelConversion,
                  child: const Text('Отмена', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ),
        // Список задач
        Expanded(
          child: ListView.separated(
            itemCount: _tasks.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) => _buildTaskTile(_tasks[index], index),
          ),
        ),
      ],
    );
  }

  Widget _buildAdvancedSettings() {
    final isLossless = _selectedFormat == AudioFormat.wav ||
        _selectedFormat == AudioFormat.flac;
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isLossless) ...[
            const Text('Битрейт:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ['64', '96', '128', '192', '256', '320', 'V0'].map((b) {
                final selected = b == _selectedBitrate;
                final cs = Theme.of(context).colorScheme;
                return ChoiceChip(
                  label: Text(b == 'V0' ? 'VBR V0' : '$b kbps'),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedBitrate = b),
                  selectedColor: Colors.orange,
                  backgroundColor: cs.surfaceContainerHighest,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : cs.onSurface,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
          SwitchListTile(
            title: const Text('Нормализация громкости (EBU R128)'),
            subtitle: const Text('Выровнять громкость всех файлов'),
            value: _normalize,
            onChanged: (v) => setState(() => _normalize = v),
            activeColor: Colors.orange,
          ),
          SwitchListTile(
            title: const Text('Сохранять теги'),
            subtitle: const Text('Артист, альбом, год, обложка'),
            value: _preserveMetadata,
            onChanged: (v) => setState(() => _preserveMetadata = v),
            activeColor: Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildTaskTile(ConvertTask task, int index) {
    final statusColor = _statusColor(task.status);
    return ListTile(
      leading: Icon(Icons.audio_file, color: statusColor),
      title: Text(
        task.inputName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                task.formattedInputSize,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              if (task.formattedOutputSize != null) ...[
                const Text(' → ', style: TextStyle(color: Colors.grey, fontSize: 12)),
                Text(
                  task.formattedOutputSize!,
                  style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold),
                ),
              ],
              const Spacer(),
              Text(
                task.status.label,
                style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (task.status == TaskStatus.converting || task.status == TaskStatus.done) ...[
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: task.progress / 100.0,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ],
          if (task.status == TaskStatus.error && task.errorMessage != null) ...[
            const SizedBox(height: 4),
            Text(
              task.errorMessage!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Colors.red),
            ),
          ],
          // Информационное сообщение для "уже существует" (цвет темы, курсив)
          if (task.status == TaskStatus.done && task.errorMessage != null) ...[
            const SizedBox(height: 4),
            Text(
              task.errorMessage!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.primary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
      trailing: _isConverting
          ? null
          : IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () => _removeTask(index),
            ),
    );
  }

  Color _statusColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.queued:
        return Colors.grey;
      case TaskStatus.converting:
        return Colors.blue;
      case TaskStatus.done:
        return Colors.green;
      case TaskStatus.error:
        return Colors.red;
      case TaskStatus.cancelled:
        return Colors.grey;
    }
  }

  // ─── Логика ──────────────────────────────────────────────────────────────

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
    );
    if (result != null && result.files.isNotEmpty) {
      _addFiles(result.files.map((f) => f.path!).whereType<String>().toList());
    }
  }

  Future<void> _pickFolder() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result == null) return;
    final dir = Directory(result);
    final entities = await dir.list(recursive: true).toList();
    final audioFiles = entities
        .whereType<File>()
        .where((f) {
          final ext = f.path.toLowerCase();
          return ext.endsWith('.mp3') ||
              ext.endsWith('.wav') ||
              ext.endsWith('.flac') ||
              ext.endsWith('.m4a') ||
              ext.endsWith('.aac') ||
              ext.endsWith('.ogg') ||
              ext.endsWith('.opus');
        })
        .map((f) => f.path)
        .toList();
    if (audioFiles.isEmpty) {
      _showSnackBar('В папке нет аудио файлов');
      return;
    }
    _addFiles(audioFiles);
  }

  void _addFiles(List<String> paths) async {
    // Сохраняем в общедоступную папку Downloads/AudioConverter/
    // которая видна из любого файлового менеджера и музыкального плеера.
    // На Android: /storage/emulated/0/Download/AudioConverter/
    final outputDirPath = '/storage/emulated/0/Download/AudioConverter';
    final outputsPath = Directory(outputDirPath);
    try {
      if (!await outputsPath.exists()) {
        await outputsPath.create(recursive: true);
      }
    } catch (e) {
      // Fallback на documents directory, если нет доступа к Downloads
      final fallback = await getApplicationDocumentsDirectory();
      final fallbackPath = Directory('${fallback.path}/converted');
      if (!await fallbackPath.exists()) {
        await fallbackPath.create(recursive: true);
      }
      // Используем fallback для всех файлов
      setState(() {
        for (final path in paths) {
          final file = File(path);
          final name = p.basenameWithoutExtension(path);
          final ext = _selectedFormat.extension;
          final outputPath = '${fallbackPath.path}/$name.$ext';
          _tasks.add(ConvertTask(
            inputPath: path,
            inputName: p.basename(path),
            inputSize: file.existsSync() ? file.lengthSync() : 0,
            outputPath: outputPath,
            format: _selectedFormat,
            bitrate: _selectedBitrate,
            normalize: _normalize,
            preserveMetadata: _preserveMetadata,
          ));
        }
      });
      return;
    }

    setState(() {
      for (final path in paths) {
        final file = File(path);
        final name = p.basenameWithoutExtension(path);
        final ext = _selectedFormat.extension;
        final outputPath = '${outputsPath.path}/$name.$ext';
        _tasks.add(ConvertTask(
          inputPath: path,
          inputName: p.basename(path),
          inputSize: file.existsSync() ? file.lengthSync() : 0,
          outputPath: outputPath,
          format: _selectedFormat,
          bitrate: _selectedBitrate,
          normalize: _normalize,
          preserveMetadata: _preserveMetadata,
        ));
      }
    });
  }

  void _removeTask(int index) {
    setState(() => _tasks.removeAt(index));
  }

  void _clearAll() {
    setState(_tasks.clear);
  }

  Future<void> _startConversion() async {
    // Пропускаем уже готовые
    final pendingTasks = _tasks.where((t) => t.status != TaskStatus.done).toList();
    if (pendingTasks.isEmpty) {
      _showSnackBar('Все файлы уже сконвертированы');
      return;
    }

    setState(() {
      _isConverting = true;
      _cancelToken.reset();
    });

    for (final task in pendingTasks) {
      if (_cancelToken.isCancelled) break;

      setState(() {
        task.status = TaskStatus.converting;
        task.progress = 0;
      });

      await ConverterService.convertOne(
        task,
        onProgress: (percent) {
          setState(() => task.progress = percent);
        },
        cancelToken: _cancelToken,
      );

      setState(() {}); // обновить статус
    }

    setState(() => _isConverting = false);

    final success = _tasks.where((t) => t.status == TaskStatus.done).length;
    final failed = _tasks.where((t) => t.status == TaskStatus.error).length;
    final cancelled = _tasks.where((t) => t.status == TaskStatus.cancelled).isNotEmpty;

    String message;
    if (cancelled) {
      message = 'Отменено. Успешно: $success';
    } else if (failed > 0) {
      message = 'Готово. Успешно: $success, ошибок: $failed';
    } else {
      message = '✓ Готово! Сконвертировано: $success';
    }

    // Показываем SnackBar с кнопкой "Открыть папку" только если есть успехи
    if (success > 0) {
      _showResultSnackBar(message);
    } else {
      _showSnackBar(message);
    }
  }

  void _showResultSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Открыть папку',
          onPressed: _openOutputFolder,
        ),
      ),
    );
  }

  Future<void> _openOutputFolder() async {
    try {
      final dir = Directory('/storage/emulated/0/Download/AudioConverter');
      if (await dir.exists()) {
        // Открываем через системный файловый менеджер
        // Используем intent через MethodChannel (упрощённо — просто показать путь)
        _showOutputDialog();
      } else {
        _showSnackBar('Папка ещё не создана');
      }
    } catch (e) {
      _showSnackBar('Ошибка: $e');
    }
  }

  void _showOutputDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📁 Где найти файлы'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Сконвертированные файлы сохранены в:'),
            SizedBox(height: 12),
            Text(
              'Download/AudioConverter/',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
            ),
            SizedBox(height: 12),
            Text('Откройте любой файловый менеджер:'),
            SizedBox(height: 4),
            Text('• Мои файлы / Files'),
            Text('• Google Files'),
            Text('• Solid Explorer'),
            SizedBox(height: 12),
            Text(
              'Папка находится во внутренней памяти → Download → AudioConverter',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _cancelConversion() {
    _cancelToken.cancel();
    _showSnackBar('Отмена…');
  }

  void _applyPreset(String key) {
    setState(() {
      switch (key) {
        case 'music':
          _selectedFormat = AudioFormat.mp3;
          _selectedBitrate = '320';
          _normalize = false;
          break;
        case 'voice':
          _selectedFormat = AudioFormat.mp3;
          _selectedBitrate = '192';
          _normalize = true;
          break;
        case 'podcast':
          _selectedFormat = AudioFormat.mp3;
          _selectedBitrate = '128';
          _normalize = true;
          break;
        case 'archive':
          _selectedFormat = AudioFormat.flac;
          _normalize = false;
          break;
      }
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  void _showAbout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Text('🎵', style: TextStyle(fontSize: 28)),
            SizedBox(width: 12),
            Text('Audio Converter'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Версия: 1.0.0'),
            SizedBox(height: 6),
            Text(
              'Разработчик: SwanLab',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
            ),
            SizedBox(height: 16),
            Text('Конвертер аудио для Android.'),
            SizedBox(height: 8),
            Text('Поддерживаемые форматы:'),
            SizedBox(height: 4),
            Text('• MP3 (libmp3lame)'),
            Text('• WAV (PCM 16-bit)'),
            Text('• M4A/AAC'),
            Text('• FLAC (без потерь)'),
            SizedBox(height: 16),
            Text(
              'Построено на Flutter + ffmpeg_kit.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            SizedBox(height: 4),
            Text(
              '© 2026 SwanLab',
              style: TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
