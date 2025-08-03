import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

abstract class PdfParserService {
  Future<Map<String, dynamic>> parse(String pdfFilePath);
}

class CliPdfParserService implements PdfParserService {
  @override
  Future<Map<String, dynamic>> parse(String pdfFilePath) async {
    String? capturedStdout;
    String? capturedStderr;
    try {
      final executableDir = p.dirname(Platform.resolvedExecutable);
      final parserPath = p.join(executableDir, 'backend', 'parser.exe');

      if (!await File(parserPath).exists()) {
        throw Exception(
            'Не найден исполняемый файл парсера по пути: $parserPath');
      }

      final processResult = await Process.run(
        parserPath,
        ['--file', pdfFilePath],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );

      capturedStdout = processResult.stdout as String?;
      capturedStderr = processResult.stderr as String?;

      // --- ИСПРАВЛЕНИЕ ЗДЕСЬ ---
      // 1. Проверяем, что stdout не null и не пустой после удаления пробелов.
      if (processResult.exitCode == 0 &&
          capturedStdout != null &&
          capturedStdout!.trim().isNotEmpty) {
        // 2. Внутри этого блока компилятор теперь "знает", что capturedStdout не может быть null.
        final Map<String, dynamic> jsonData = jsonDecode(capturedStdout!);
        return jsonData;
      } else {
        // Если код выхода 0, но stdout пустой, это тоже считаем ошибкой.
        if (processResult.exitCode == 0) {
          throw Exception(
              'Парсер завершился успешно, но не вернул никаких данных (stdout пуст).\n\n'
              '--- STDERR ---\n$capturedStderr');
        }
        // Иначе, это ошибка самого парсера.
        throw Exception(
            'Ошибка парсера (код ${processResult.exitCode}): $capturedStderr');
      }
    } catch (e) {
      // Этот блок остается без изменений, он по-прежнему полезен для отладки.
      throw Exception(
          'Внутренняя ошибка при вызове парсера: ${e.toString()}\n\n'
          '--- STDOUT ---\n$capturedStdout\n'
          '--- STDERR ---\n$capturedStderr');
    }
  }
}
